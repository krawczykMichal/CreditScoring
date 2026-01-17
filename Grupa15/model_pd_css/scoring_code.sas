/* =====================================================
   PD CSS – MODEL RYZYKA KREDYTU GOTÓWKOWEGO
   Wersja: POPRAWIONA
   ===================================================== */

options nomprint symbolgen;

/* 1. LIBNAME */
libname inlib "/workspaces/workspace/ASBSAS/inlib";

/* 2. Wczytanie danych i filtrowanie czasu */
data abt_prep;
    set out.abt_app;
    
    /* Bezpieczniejsza konwersja daty, jeśli period jest tekstem */
    /* Zakładamy, że period to tekst 'YYYYMM' */
    if input(period, best.) >= 197501 and input(period, best.) <= 198712;
    
    /* Filtrowanie produktu i defaultu */
    if act_ccss_n_loan > 0;
    if default12 in (0,1);
run;

/* 5. Losowy podział train/valid (Zastąpiono ranuni nowszym rand) */
data train valid;
    set abt_prep;
    call streaminit(12345); /* Inicjalizacja ziarna */
    u = rand('uniform');
    if u <= 0.7 then output train;
    else output valid;
    drop u;
run;

/* 6. Zmienne do modelu */
%let model_vars_final =
    act_ccss_dueutl
    act_ccss_maxdue
    act_ccss_utl
    act_ccss_n_statC
    act3_n_arrears
    act6_n_arrears
    act9_n_arrears
    act12_n_arrears
    agr6_Mean_CMaxC_Due
    agr12_Mean_CMaxA_Due
;

/* 7 & 8. Model logistyczny - JEDNO URUCHOMIENIE */
/* Pobieramy parametry (ods output) i zapisujemy model w jednym kroku */
proc logistic data=train descending outest=betas;
    model default12 = &model_vars_final;
    ods output ParameterEstimates = pd_css_params;

    /* POPRAWIONA LINIA:
       Instrukcja SCORE tworzy zmienną P_1 (prawdopodobieństwo zdarzenia).
       Zmieniamy jej nazwę na PD_CSS_RAW w locie. */
    score data=valid out=score_valid(rename=(P_1=PD_CSS_RAW));
run;

/* 9. Pobranie parametrów do makrozmiennych (SQL) */
proc sql noprint;
    /* Pobranie Interceptu (BARDZO WAŻNE) */
    select estimate into :intercept 
    from pd_css_params 
    where variable='Intercept';

    /* Liczba zmiennych */
    select count(*) into :nvars from pd_css_params where variable ne 'Intercept';

    /* Pobranie zmiennych i oszacowań */
    select variable, estimate
    into :var1-:var999, :est1-:est999
    from pd_css_params
    where variable ne 'Intercept';
quit;

/* =====================================================
   10. SCORECARD – NAPRAWA BŁĘDU SKŁADNIOWEGO
   Logika została zamknięta w makrze %macro
   ===================================================== */

%macro calculate_score(input_ds, output_ds);
    data &output_ds;
        set &input_ds;

        /* Startujemy od Interceptu przeskalowanego tak samo jak zmienne */
        /* Zakładam Twoją logikę: punkty = (beta * x) / 0.05 */
        
        SCORECARD_POINTS = (&intercept / 0.05);

        %do i=1 %to &nvars;
            %let v = &&var&i;
            %let b = &&est&i;

            /* NAPRAWA: Obsługa braków danych. 
               Funkcja coalesce(zmienna, 0) wstawi 0 zamiast kropki,
               dzięki czemu wynik nie zniknie. */
            
            _val_&v = coalesce(&v, 0);

            /* Obliczenie punktów cząstkowych */
            PSC_&v = (&b * _val_&v) / 0.05;
            
            /* Sumowanie */
            SCORECARD_POINTS = sum(SCORECARD_POINTS, PSC_&v);
        %end;
        
        drop _val_:; /* Usunięcie zmiennych pomocniczych */
    run;
%mend;

/* Uruchomienie makra */
%calculate_score(abt_prep, scorecard_css);


/* 11. Kalibracja PD z punktów */

/* Średni default z populacji */
proc sql noprint;
    select mean(default12) into :avg_pd from abt_prep; /* Zmieniono zbiór na abt_prep */
quit;

/* Parametry kalibracji */
%let b_calib = -0.05;

data _null_;
    avg_pd = &avg_pd;
    /* Zabezpieczenie matematyczne */
    if avg_pd > 0 and avg_pd < 1 then 
        a_calib = log(avg_pd/(1-avg_pd));
    else 
        a_calib = 0;
        
    call symputx('a_calib', a_calib);
run;

/* 12. Finalne PD */
data out.abt_app;
    set scorecard_css;

    /* Formuła: PD = 1 / (1 + exp( - (Alpha + Beta * Score) )) */
    logit_calib = &a_calib + (&b_calib * SCORECARD_POINTS);
    PD_css_scorecard = 1 / (1 + exp(-logit_calib));
run;

