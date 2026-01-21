/* ==========================================================================
   FINAL PROFIT CALCULATION - ZOPTYMALIZOWANE PARAMETRY
   ========================================================================== */
options mprint symbolgen;
libname out "/workspaces/workspace/Grupa15";

/* 1. PARAMETRY FINANSOWE (Stałe) */
%let apr_ins=0.01;
%let apr_css=0.18;
%let lgd_ins=0.45;
%let lgd_css=0.55;

/* 2. PARAMETRY DECYZYJNE (Z Twojej optymalizacji) */
/* To są wartości, które maksymalizują zysk */
%let pd_css_cutoff  = 0.3788;  /* CSS: Akceptujemy do ~38% ryzyka */
%let pd_ins_hard    = 0.3965;  /* INS: Twarde odcięcie na ~40% ryzyka */
%let pd_ins_soft    = 0.15;    /* INS: Próg weryfikacji cross-sellu */
%let pr_req         = 0.01;    /* INS: Wymagane prawdopodobieństwo reakcji */

/* 3. PRZELICZENIE I APLIKACJA DECYZJI */
data out.final_simulation;
    set out.abt_scored_final;
    
    /* Filtrujemy tylko zakres historyczny */
    where '197501'<=period<='198712';
    
    /* Obsługa braków danych w defaultach */
    if default12 in (0,.i,.d) then default12=0;
    if default_cross12 in (0,.i,.d) then default_cross12=0;

    /* A. KALIBRACJA (Punkty -> PD) */
    /* Używamy wzorów z Twojego modelu */
    risk_score = SCORECARD_POINTS;
    pd_ins = 1 / (1 + exp( - (-0.032205144 * risk_score + 9.4025558419) ));
    pd_css = 1 / (1 + exp( - (-0.028682728 * risk_score + 8.1960829753) ));
    
    /* Mapowanie zmiennych z procesu ETL */
    pd_cross_css = prob_default_css_cross;
    pr = prob_response_css;

    /* B. OBLICZENIA FINANSOWE (Income & Loss) */
    /* Ustawienie parametrów per produkt */
    if product='ins' then do;
        lgd=&lgd_ins; apr=&apr_ins/12;
    end;
    else if product='css' then do;
        lgd=&lgd_css; apr=&apr_css/12;
    end;
    
    /* Profit z produktu głównego */
    EL = 0;
    if default12=1 then EL = app_loan_amount * lgd;
    
    installment = 0;
    if app_n_installments > 0 then
        installment = app_loan_amount*apr*((1+apr)**app_n_installments)/(((1+apr)**app_n_installments)-1);
    
    Income = 0;
    if default12=0 then Income = app_n_installments*installment - app_loan_amount; /* Uproszczone: Raty - Kapitał */
    
    Profit = Income - EL;

    /* Profit z Cross-Sell (tylko parametry CSS) */
    lgd_cross = &lgd_css; 
    apr_cross = &apr_css/12;
    
    EL_cross = 0;
    if default_cross12=1 then EL_cross = cross_app_loan_amount * lgd_cross;
    
    installment_cross = 0;
    if cross_app_n_installments > 0 then
        installment_cross = cross_app_loan_amount*apr_cross*((1+apr_cross)**cross_app_n_installments)/(((1+apr_cross)**cross_app_n_installments)-1);
        
    Income_cross = 0;
    if default_cross12=0 then Income_cross = cross_app_n_installments*installment_cross - cross_app_loan_amount;
    
    Profit_cross = Income_cross - EL_cross;


    /* C. SYMULACJA DECYZJI (Zastosowanie Twoich parametrów) */
    simulated_decision = 'A'; /* Domyślnie Akceptuj */

    /* Logika dla CSS */
    if product='css' and pd_css > &pd_css_cutoff then simulated_decision='D';

    /* Logika dla INS */
    if product='ins' then do;
        /* Twarde odcięcie */
        if pd_ins > &pd_ins_hard then simulated_decision='D';
        /* Odcięcie warunkowe (Cross-sell) */
        else if (pd_ins > &pd_ins_soft) and (pr < &pr_req or pd_cross_css > &pd_css_cutoff) then simulated_decision='D';
    end;
    
    /* Zerowanie profitu dla odrzuconych (dla celów raportowych) */
    if simulated_decision = 'D' then do;
        Profit = 0;
        Profit_cross = 0;
    end;

    Total_Profit = Profit + Profit_cross;
run;

/* 4. RAPORT KOŃCOWY - POPRAWIONA SKŁADNIA TABULATE */
title "OSTATECZNY WYNIK FINANSOWY (Dla parametrów: CSS=&pd_css_cutoff, INS=&pd_ins_hard)";
proc tabulate data=out.final_simulation;
    class product simulated_decision;
    var Total_Profit;
    
    /* Wyświetlamy tylko decyzje ACCEPT, bo one generują realny wynik */
    where simulated_decision = 'A';
    
    table product, 
          simulated_decision * (
              N='Liczba Umów'*f=comma12. 
              Total_Profit * Sum='Całkowity Zysk (PLN)' * f=comma20.0 /* Tutaj dodano nazwę zmiennej */
          )
          / box='Produkt (Tylko Zaakceptowane)';
run;
title;