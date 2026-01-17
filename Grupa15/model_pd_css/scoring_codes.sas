/* =====================================================
   PD CSS – MODEL RYZYKA KREDYTU GOTÓWKOWEGO
   Kompletny plik SAS: model + scorecard + kalibracja
   ===================================================== */

/* 1. LIBNAME */
libname data "F:\SGH\credit scoring\software\software\ASB_SAS\inlib";

/* 2. Wczytanie danych */
data abt_all;
    set data.abt_app;
run;

/* 3. Okres 1975–1987 */
data abt_time;
    set abt_all;
    if '197501' <= period <= '198712';
run;

/* 4. Produkt CSS */
data abt_css;
    set abt_time;
    if act_ccss_n_loan > 0;
    if default12 in (0,1);
run;

/* 5. Losowy podzia³ train/valid */
data abt_css_rnd;
    set abt_css;
    u = ranuni(12345);
run;

data train valid;
    set abt_css_rnd;
    if u <= 0.7 then output train;
    else output valid;
run;

/* 6. Zmienne koñcowe do modelu */
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

/* 7. Model logistyczny PD_CSS */
proc logistic data=train descending;
    model default12 = &model_vars_final;
    output out=score_train p=PD_CSS;
run;

proc logistic data=train descending;
    model default12 = &model_vars_final;
    score data=valid out=score_valid p=PD_CSS;
run;

/* 8. Pobranie parametrów modelu */
ods output ParameterEstimates = pd_css_params;

proc logistic data=train descending;
    model default12 = &model_vars_final;
run;

ods output close;

/* 9. Pobranie parametrów do makr */
proc sql noprint;
    select estimate into :intercept
    from pd_css_params
    where variable='Intercept';

    select variable, estimate
    into :var1-:var999, :est1-:est999
    from pd_css_params
    where variable ne 'Intercept';
    %let nvars=&sqlobs;
quit;

/* 10. SCORECARD – przeliczenie modelu na punkty */
data scorecard_css;
    set abt_css;

    SCORECARD_POINTS = 0;

    %do i=1 %to &nvars;
        %let v = &&var&i;
        %let b = &&est&i;

        /* Punkty = beta * wartoœæ / 0.05 */
        PSC_&v = &b * &v / 0.05;
        SCORECARD_POINTS + PSC_&v;
    %end;

run;

/* 11. Kalibracja PD z punktów */

/* Œredni default */
proc sql noprint;
    select mean(default12) into :avg_pd from abt_css;
quit;

/* Ustalony wspó³czynnik nachylenia */
%let b = -0.05;

/* Wyznaczenie interceptu kalibracyjnego */
data _null_;
    avg_pd = &avg_pd;
    b = &b;
    a = log(avg_pd/(1-avg_pd));
    call symputx('a', a);
run;

/* 12. Finalne PD_css_scorecard */
data pd_css_final;
    set scorecard_css;

    PD_css_scorecard = 1/(1+exp(-(&a + &b * SCORECARD_POINTS)));
run;

/* =====================================================
   KONIEC PLIKU
   ===================================================== */

