/* ==========================================================================
   SCORING I DECYZJA KREDYTOWA - ZINTEGROWANY KOD
   ========================================================================== */

libname inlib "/workspaces/workspace/ASBSAS/inlib";
libname out "/workspaces/workspace/Grupa15";

data out.abt_app;
    set inlib.abt_app;
run;

/* 1. Uruchomienie modeli (zakładamy, że te skrypty zasilają inlib.abt_app 
      lub tworzą zbiory, które zostały wcześniej złączone) */
%include "/workspaces/workspace/Grupa15/model_pd_css/scoring_code.sas";
%include "/workspaces/workspace/Grupa15/model_pd_ins/scoring_code.sas";
%include "/workspaces/workspace/Grupa15/model_pd_css_cross/scoring_code.sas";

data out.abt_app;
    set out.abt_app;
    %include "/workspaces/workspace/Grupa15/model_pr_css_cross/scoring_code.sas";
run;

data out.abt_scored_final;
    length decision $ 30 rejection_reason $ 30;

    set out.abt_app;

    /* --- SEKCJA 2: Inicjalizacja zmiennych decyzyjnych --- */
        
    decision = 'ACCEPT'; 
    rejection_reason = 'N/A';
    cross_sell_offer = 1; 

    _prod_norm = strip(lowcase(product));


    /* --- SEKCJA 3: Logika Biznesowa --- */

    /* Sprawdzenie czy klient jest aktywny (flaga systemowa) */
    if active_customer_flag = 0 then do;
        decision = 'DECLINE';
        rejection_reason = '998: Not active customer';
        cross_sell_offer = 0; 
    end;
    
    else do; 

    /* --- SEKCJA 3: Logika Biznesowa (ZOPTYMALIZOWANA) --- */

    if active_customer_flag = 0 then do;
        decision = 'DECLINE';
        rejection_reason = '998: Not active customer';
        cross_sell_offer = 0; 
    end;
    
    else do; 

        /* =========================================================
           PRODUKT INS: ZMIANA STRATEGII NA RENTOWNOŚĆ
           Zamiast odrzucać po punktach, odrzucamy tylko te, 
           które przynoszą stratę (czyli bardzo małe kwoty).
           ========================================================= */
        if _prod_norm = 'ins' then do;
            /* Parametry: Marża ok. 9%, Koszt 150 zł, Ryzyko 4.4% */
            /* Próg rentowności (Break-even): Kredyt ok. 1200 PLN */
            
            if app_loan_amount < 1200 then do;
                decision = 'DECLINE';
                rejection_reason = 'Business: Unprofitable (Small Amount)';
            end;
            
            /* Opcjonalnie: Odrzucamy tylko ekstremalnie ryzykowne punkty (jeśli takie są) */
            /* W Twoim zbiorze max to 413, więc ustawiamy bezpiecznik wyżej */
            else if SCORECARD_PROB > 0.09 then do; 
                decision = 'DECLINE';
                rejection_reason = 'Risk: Very High Score INS';
            end;
        end;

        /* =========================================================
           PRODUKT CSS: NOWY PRÓG PD = 27%
           Zwiększamy cut-off z 15% na 27%, bo tacy klienci wciąż zarabiają.
           ========================================================= */
        else if _prod_norm = 'css' then do;
            if missing(PD_css_scorecard) then do;
                /* Brak oceny -> Manual */
                decision = 'MANUAL';
                rejection_reason = 'ERR: Missing Score CSS';
            end;
            else if PD_css_scorecard > 0.2727 then do;
                decision = 'DECLINE';
                rejection_reason = 'Risk: High PD CSS (>27%)';
            end;
        end;
        
        else do;
            decision = 'ERROR';
            rejection_reason = cat('Unknown Product Type: ', product);
        end;

        /* Cross-Sell bez zmian lub lekka korekta */
        if cross_sell_offer = 1 then do;
            if prob_default_css_cross > 0.20 then cross_sell_offer = 0; /* Zwiększono z 0.12 */
            if prob_response_css < 0.02 then cross_sell_offer = 0;
            if missing(prob_default_css_cross) or missing(prob_response_css) then cross_sell_offer = 0;
        end;

    end;
    drop _prod_norm;
keep 
        /* Klient i Wniosek */
        cid aid period product 
        app_loan_amount app_n_installments 
        
        /* Decyzja */
        decision rejection_reason cross_sell_offer
        
        /* Wyniki Modeli (Score/PD) */
        PD_css_scorecard          /* PD dla produktu CSS */
        SCORECARD_POINTS          /* Punkty dla produktu INS */
        prob_default_css_cross    /* PD dla oferty Cross-Sell */
        prob_response_css         /* Prawdopodobieństwo zakupu Cross-Sell */
    ;
end;

/* Raportowanie wyników */
title "Podsumowanie decyzji kredytowych";
proc freq data=out.abt_scored_final;
    tables decision rejection_reason cross_sell_offer product*decision / list missing;
run;
title;