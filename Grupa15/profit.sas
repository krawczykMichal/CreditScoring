/* 1. Ustawienie biblioteki (tam gdzie zapisałeś plik w poprzednim kroku) */
libname out "/workspaces/workspace/Grupa15";

/* 2. Parametry Symulacji (identyczne jak w mojej weryfikacji) */
%let oprocentowanie = 0.14; /* 14% */
%let koszt_kapitalu = 0.05; /* 5% */
%let LGD            = 0.55; /* 55% straty przy default */
%let koszt_staly    = 150;  /* 150 PLN za wniosek */

/* 3. Przeliczenie */
data work.weryfikacja_zysku;
    set out.abt_scored_final;
    
    /* Bierzemy pod uwagę TYLKO zaakceptowane wnioski */
    where decision = 'ACCEPT';

    /* --- Ustalenie PD (Prawdopodobieństwa Defaultu) --- */
    /* Logika: CSS bierze z modelu, INS przyjmujemy stałe 8% (bo mamy tam punkty), reszta 10% */
    
    length prod_norm $ 3;
    prod_norm = strip(lowcase(product));

    if prod_norm = 'css' then do;
        /* Jeśli brak PD, zakładamy bezpiecznie 5% */
        Calc_PD = coalesce(PD_css_scorecard, 0.05);
    end;
    else if prod_norm = 'ins' then do;
        /* Dla INS w modelu były punkty, więc do symulacji finansowej 
           przyjmujemy stałe ryzyko portfela na poziomie 8% */
        Calc_PD = 0.08; 
    end;
    else do;
        Calc_PD = 0.10;
    end;

    /* Zabezpieczenie zakresu PD 0-1 */
    if Calc_PD > 1 then Calc_PD = 1;
    if Calc_PD < 0 then Calc_PD = 0;


    /* --- Wyliczenia Finansowe --- */
    
    /* Czas trwania w latach (jeśli brak rat, zakładamy 2 lata) */
    Duration_Years = coalesce(app_n_installments, 24) / 12;

    /* 1. Przychód odsetkowy (Revenue) */
    /* Kwota * Marża (14% - 5%) * Lata */
    Revenue = app_loan_amount * (&oprocentowanie - &koszt_kapitalu) * Duration_Years;

    /* 2. Oczekiwana Strata (Expected Loss) */
    /* Kwota * PD * LGD */
    Expected_Loss = app_loan_amount * Calc_PD * &LGD;

    /* 3. Zysk Netto (Profit) */
    /* Przychód - Koszt Stały - Strata */
    Profit = Revenue - &koszt_staly - Expected_Loss;

    format Revenue Expected_Loss Profit comma16.2;
run;

/* 4. Raport Wynikowy (Podsumowanie) */
title "Weryfikacja Zysków (Decision = ACCEPT)";
proc sql;
    /* Podsumowanie ogólne */
    select 
        "CALY PORTFEL" as Kategoria,
        count(*) as Liczba_Umow,
        sum(Revenue) as Suma_Przychodow format=comma16.2,
        sum(Profit) as Suma_Zysku_Netto format=comma16.2
    from work.weryfikacja_zysku;

    /* Podsumowanie per produkt */
    select 
        product,
        count(*) as Liczba_Umow,
        sum(Revenue) as Suma_Przychodow format=comma16.2,
        sum(Profit) as Suma_Zysku_Netto format=comma16.2
    from work.weryfikacja_zysku
    group by product;
quit;
title;