/* (c) Karol Przanowski - Modified Version */
/* Tylko obliczanie zysku (Profit Calculation) */

options mprint;

/* 1. Ścieżki i Biblioteki (Dostosuj do swojego środowiska) */
libname out "/workspaces/workspace/Grupa15";


/* 2. Parametry Finansowe (Symulacja biznesowa) */
%let apr_ins=0.01;       /* Oprocentowanie roczne - Raty */
%let apr_css=0.18;       /* Oprocentowanie roczne - Gotówka */
%let lgd_ins=0.45;       /* Loss Given Default - Raty */
%let lgd_css=0.55;       /* Loss Given Default - Gotówka */
%let provision_ins=0;    /* Prowizja - Raty */
%let provision_css=0;    /* Prowizja - Gotówka */

/* 3. Główny Data Step - Obliczanie Zysku */
data out.profit_calculated;
    set out.abt_scored_final; /* Tabela wejściowa z danymi o klientach i kwotach */

    where upcase(decision) = "ACCEPT";

    /* Czyszczenie flag defaultu (zgodnie z oryginałem) */
    if default12 in (0,.i,.d) then default12=0;
    if default_cross12 in (0,.i,.d) then default_cross12=0;

    /* Przypisanie parametrów w zależności od produktu */
    if product='ins' then do;
        lgd = &lgd_ins;
        apr = &apr_ins/12; /* Konwersja na oprocentowanie miesięczne */
        provision = &provision_ins;
    end;
    else if product='css' then do;
        lgd = &lgd_css;
        apr = &apr_css/12;
        provision = &provision_css;
    end;

    /* Parametry dla produktu Cross-Sell (zawsze Gotówka/CSS w tym scenariuszu) */
    lgd_cross = &lgd_css;
    apr_cross = &apr_css/12;
    provision_cross = &provision_css;

    /* --- OBLICZENIA DLA GŁÓWNEGO PRODUKTU --- */
    
    /* 1. Expected Loss (EL) - tutaj jako strata zrealizowana */
    EL = 0;
    if default12=1 then EL = app_loan_amount * lgd;

    /* 2. Rata (Installment) - wzór na ratę równą */
    if apr > 0 then do;
        installment = app_loan_amount * apr * ((1+apr)**app_n_installments) / 
                      (((1+apr)**app_n_installments)-1);
    end;
    else do;
        /* Zabezpieczenie na wypadek apr=0 */
        installment = app_loan_amount / app_n_installments;
    end;

    /* 3. Przychód (Income) */
    Income = 0;
    /* Zakładamy, że jeśli nie ma defaultu, klient spłacił wszystko + prowizję */
    /* Uwaga: W oryginale wzór: kwota*(prowizja-1) odejmuje kapitał, 
       żeby Income reprezentował czysty zarobek odsetkowy/prowizyjny netto przed odjęciem EL?
       Analiza oryginału: Income = Raty - Kapitał + Prowizja. */
    if default12=0 then Income = (app_n_installments * installment) 
                                 + app_loan_amount * (provision - 1);

    /* 4. Zysk (Profit) */
    /* Jeśli default: Profit = 0 - Strata. Jeśli spłata: Profit = Odsetki - 0 */
    Profit = income - el;


    /* --- OBLICZENIA DLA PRODUKTU CROSS-SELL --- */
    
    EL_cross = 0;
    if default_cross12=1 then EL_cross = cross_app_loan_amount * lgd_cross;

    if apr_cross > 0 and cross_app_n_installments > 0 then do;
        installment_cross = cross_app_loan_amount * apr_cross * ((1+apr_cross)**cross_app_n_installments) /
                            (((1+apr_cross)**cross_app_n_installments)-1);
    end;
    else installment_cross = 0;

    Income_cross = 0;
    if default_cross12=0 and cross_app_n_installments > 0 then 
        Income_cross = (cross_app_n_installments * installment_cross)
                       + cross_app_loan_amount * (provision_cross - 1);
    
    Profit_cross = income_cross - el_cross;


    /* Formatowanie i czyszczenie */
    year = compress(put(input(period,yymmn6.),year4.));

    /* Zachowaj tylko potrzebne zmienne */
    keep aid cid product period year
         app_loan_amount app_n_installments 
         cross_app_loan_amount cross_app_n_installments
         default12 default_cross12
         EL Income Profit 
         EL_cross Income_cross Profit_cross;
run;

/* Podgląd wyników */
proc means data=out.profit_calculated n mean sum min max maxdec=2;
    var Profit Profit_cross;
    class product;
run;