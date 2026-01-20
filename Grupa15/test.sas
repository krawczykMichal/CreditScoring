/* (c) Karol Przanowski - Profit Calc Implementation */
/* Adapted for current workspace environment */

options mprint symbolgen;

/* 1. Ustawienia środowiska */
libname out "/workspaces/workspace/Grupa15";

/* Parametry finansowe */
%let apr_ins=0.01;
%let apr_css=0.18;
%let lgd_ins=0.45;
%let lgd_css=0.55;
%let provision_ins=0;
%let provision_css=0;

/* 2. Przygotowanie danych (Zamiast ładowania zewnętrznych plików) */
data cal;
    set out.abt_scored_final; /* Korzystamy z gotowego zbioru */
    
    /* Filtrowanie okresu i decyzji (ACCEPT w Twoim zbiorze) */
    where '197501'<=period<='198712' and decision='ACCEPT';
    
    /* Obsługa braków */
    if default12 in (0,.i,.d) then default12=0;
    if default_cross12 in (0,.i,.d) then default_cross12=0;
run;

/* 3. Kalibracja i Wyliczenie PD (Symulacja procesu scoringowego) */
data cal4;
    set cal;

    /* A. MODEL INS & CSS */
    /* Używamy punktów ze zbioru i wzoru z Twojego kodu.
       Wzór ten ma ujemną betę przy score (-0.03...), co PRAWIDŁOWO
       odwraca logikę (Wysoki Score -> Niskie PD) */
    
    risk_score = SCORECARD_POINTS; 

    /* Formuła dla INS */
    pd_ins = 1 / (1 + exp( - (-0.032205144 * risk_score + 9.4025558419) ));

    /* Formuła dla CSS */
    pd_css = 1 / (1 + exp( - (-0.028682728 * risk_score + 8.1960829753) ));

    /* B. MODEL CROSS SELL & RESPONSE */
    /* Ponieważ nie mamy osobnych punktów 'SCORE' dla modeli cross i response w tym zbiorze,
       mapujemy gotowe prawdopodobieństwa wyliczone wcześniej w procesie. 
       Zakładamy, że są to Prawdopodobieństwa Defaultu (PD) i Reakcji (PR). */
    
    pd_cross_css = prob_default_css_cross;
    pr = prob_response_css;

run;

/* 4. Obliczenia Profitowości (Zgodnie z Twoim kodem) */
data out.profit_cal; /* Zapisujemy do biblioteki OUT */
    set cal4;

    /* Przypisanie parametrów w zależności od produktu */
    if product='ins' then do;
        lgd=&lgd_ins;
        apr=&apr_ins/12;
        provision=&provision_ins;
    end;
    if product='css' then do;
        lgd=&lgd_css;
        apr=&apr_css/12;
        provision=&provision_css;
    end;
    
    /* Parametry Cross-Sell */
    lgd_cross=&lgd_css;
    apr_cross=&apr_css/12;
    provision_cross=&provision_css;

    /* --- Profit Produkt Główny --- */
    EL=0;
    if default12=1 then EL=app_loan_amount*lgd;
    
    installment=0;
    if app_n_installments > 0 then
        installment=app_loan_amount*apr*((1+apr)**app_n_installments)/(((1+apr)**app_n_installments)-1);
    
    Income=0;
    if default12=0 then Income=app_n_installments*installment + app_loan_amount*(provision-1);
    
    Profit=Income-EL;

    /* --- Profit Cross-Sell --- */
    EL_cross=0;
    if default_cross12=1 then EL_cross=cross_app_loan_amount*lgd_cross;
    
    installment=0;
    if cross_app_n_installments > 0 then
        installment=cross_app_loan_amount*apr_cross*((1+apr_cross)**cross_app_n_installments)/(((1+apr_cross)**cross_app_n_installments)-1);
    
    Income_cross=0;
    if default_cross12=0 then Income_cross=cross_app_n_installments*installment + cross_app_loan_amount*(provision_cross-1);
    
    Profit_cross=Income_cross-EL_cross;

    year=compress(put(input(period,yymmn6.),year4.));

    /* Zachowujemy kluczowe zmienne */
    keep aid cid product cross: pd: pr: year el: income: profit: app_loan_amount;
run;

/* ==========================================================================
   ANALIZA WYNIKÓW (Szukanie Cut-offów)
   ========================================================================== */

/* 1. Analysis per cash CSS product */
title "Analiza Zyskowności CSS wg PD";
proc means data=out.profit_cal noprint nway;
    class pd_css;
    var profit;
    output out=cash sum(profit)=profit n(profit)=n;
    where product='css';
run;

proc sort data=cash;
    by pd_css;
run;

proc sql noprint;
    select sum(n) into :n_obs from cash;
quit;
%put Liczba obserwacji CSS: &n_obs;

data cash_cum;
    set cash;
    n_cum+n;
    ar=n_cum/&n_obs;
    profit_cum+profit;
    format pd: ar: nlpct12.2 profit: nlnum18.;
run;

proc sort data=cash_cum;
    by descending profit_cum;
run;

proc print data=cash_cum(obs=10);
    var pd_css ar profit profit_cum;
    title "Top 10 Cut-offów dla CSS (gdzie Profit Cum jest najwyższy)";
run;


/* Ustawienie cut-offu dla CSS na podstawie wyników */
/* Tutaj wstaw wartość z wiersza, gdzie profit_cum jest max */
%let pd_css=0.3788; 


/* 2. Analysis per Instalment Loan (INS) */
title "Analiza Zyskowności INS (z uwzględnieniem Cross-Sell)";
data instalment;
    set out.profit_cal;
    /* Jeśli cross-sell jest zbyt ryzykowny, zerujemy zysk z niego */
    if pd_cross_css > &pd_css then profit_cross=0;
    
    profit_global = profit_cross + profit;
    where product='ins';
    format profit: nlnum18. pr pd_ins nlpct12.2;
run;

proc rank data=instalment out=instalment_rank groups=5;
    var pr pd_ins;
    ranks rpr rpd_ins;
run;

proc means data=instalment_rank noprint nway;
    class rpr rpd_ins;
    var profit_global pr pd_ins;
    output out=instalment_rank_means 
        sum(profit_global)=profit_global n(profit_global)=n
        max(pr pd_ins)=max_pr max_pd_ins
        min(pr pd_ins)=min_pr min_pd_ins
    ;
run;

proc sort data=instalment_rank_means;
    by descending profit_global;
run;

proc print data=instalment_rank_means;
    title "Segmenty INS (Ranking wg Profit Global)";
run;

%let pd_ins1 = 0.3965; /* Twarde odcięcie dla INS */

/* Parametry pomocnicze dla INS (Cross-sell) */
/* Luzujemy, bo próbka jest mała, a zależy nam na wolumenie */
%let pd_ins2 = 0.15;   
%let pr2 = 0.01;

/* ==========================================================================
   FINALNY TEST SYMULACJI
   ========================================================================== */
title "Symulacja Decyzji i Profitu";
data alltest;
    set out.profit_cal;
    
    /* Domyślnie akceptujemy */
    decision='A';
    
    /* Odrzucamy CSS jeśli zbyt duże ryzyko */
    if product='css' and pd_css > &pd_css then decision='D';
    
    /* Odrzucamy INS jeśli:
       1. Zbyt duże ryzyko (powyżej górnego progu)
       2. Lub średnie ryzyko ORAZ słaby potencjał cross-sell (niski response lub wysokie ryzyko cross) */
    if product='ins' and pd_ins > &pd_ins1 then decision='D';
    if product='ins' and &pd_ins1 >= pd_ins > &pd_ins2 and 
        (pr < &pr2 or pd_cross_css > &pd_css) then decision='D';
        
    format profit: nlnum18. pr pd_ins pd_css nlpct12.2;
run;

proc tabulate data=alltest;
    class product decision;
    var profit;
    table product, decision='' all, profit=''*
    (n*f=nlnum14. colpctn*f=nlnum12.2 sum*f=nlnum14.);
run;
title;