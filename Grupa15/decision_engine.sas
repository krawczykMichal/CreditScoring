/* ==========================================================================
   AUDYT FINANSOWY DECYZJI (Na podstawie istniejącej kolumny rejection_reason)
   ========================================================================== */
options mprint symbolgen;
libname out "/workspaces/workspace/Grupa15";

/* 1. PARAMETRY FINANSOWE */
%let apr_ins=0.01;
%let apr_css=0.18;
%let lgd_ins=0.45;
%let lgd_css=0.55;

/* 2. PRZELICZENIE WYNIKU FINANSOWEGO DLA KAŻDEGO WNIOSKU */
data out.audit_results;
    set out.abt_scored_final;
    
    /* Analizujemy okres historyczny */
    where '197501'<=period<='198712';

    /* Obsługa braków w danych o spłacie (default) */
    if default12 in (0,.i,.d) then default12=0;
    if default_cross12 in (0,.i,.d) then default_cross12=0;

    /* A. Ustawienie parametrów per produkt */
    if product='ins' then do;
        lgd=&lgd_ins; 
        apr=&apr_ins/12;
    end;
    else if product='css' then do;
        lgd=&lgd_css; 
        apr=&apr_css/12;
    end;

    /* B. Obliczenie wyniku z PRODUKTU GŁÓWNEGO */
    EL = 0;
    if default12=1 then EL = app_loan_amount * lgd;
    
    installment = 0;
    if app_n_installments > 0 then
        installment = app_loan_amount*apr*((1+apr)**app_n_installments)/(((1+apr)**app_n_installments)-1);
    
    Income = 0;
    if default12=0 then Income = app_n_installments*installment - app_loan_amount;
    
    Profit = Income - EL;

    /* C. Obliczenie wyniku z CROSS-SELL */
    /* (Doliczamy go, aby mieć pełny obraz wartości klienta) */
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

    /* Łączny wynik finansowy klienta (teoretyczny) */
    Total_Profit = Profit + Profit_cross;

run;

/* 3. RAPORT: ZYSK LUB STRATA WG POWODU ODRZUCENIA */
title "Audyt Decyzji: Czy słusznie odrzuciliśmy tych klientów?";
title2 "Dla ODRZUCONYCH: Ujemny wynik = Uniknięta strata (Sukces) | Dodatni wynik = Utracony zysk (Koszt)";

proc tabulate data=out.audit_results;
    class decision rejection_reason;
    var Total_Profit;
    
    table decision * rejection_reason,
          N='Liczba Wniosków'*f=comma12. 
          Total_Profit * Sum='Wynik Finansowy (PLN)'*f=comma20.0
          / box='Decyzja / Powód';
run;
title;
title2;