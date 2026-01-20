/* ==========================================================================
   SCORING I DECYZJA KREDYTOWA - KOD POPRAWIONY (PROFIT FIX)
   ========================================================================== */

libname inlib "/workspaces/workspace/ASBSAS/inlib";
libname out "/workspaces/workspace/Grupa15";

/* 1. Przygotowanie danych wejściowych */
data out.abt_app;
    set inlib.abt_app;
run;

/* 2. Uruchomienie modeli scoringowych 
   Uwaga: Modele wyliczają zmienne punktowe i prawdopodobieństwa.
   PD_css_scorecard -> Okazało się być "Prawdopodobieństwem Spłaty" (Im wyższe, tym lepiej) */
%include "/workspaces/workspace/Grupa15/model_pd_css/scoring_code.sas";
%include "/workspaces/workspace/Grupa15/model_pd_ins/scoring_code.sas";
%include "/workspaces/workspace/Grupa15/model_pd_css_cross/scoring_code.sas";

data out.abt_app;
    set out.abt_app;
    %include "/workspaces/workspace/Grupa15/model_pr_css_cross/scoring_code.sas";
run;

/* 3. SILNIK DECYZYJNY */
data out.abt_scored_final;
    length decision $ 30 rejection_reason $ 30;
    set out.abt_app;

    /* --- INICJALIZACJA ZMIENNYCH --- */
    decision = 'ACCEPT';
    rejection_reason = 'N/A';
    cross_sell_offer = 1; 

    _prod_norm = strip(lowcase(product));

    /* --- PARAMETRY ODCIĘCIA (CUT-OFFS) --- */
    /* Ustawione na podstawie analizy zyskowności (Break-even analysis) */
    /* Pamiętaj: Zmienne oznaczają "Prawdopodobieństwo Dobrego Klienta" */
    
    _cutoff_css = 0.81; /* Odrzucamy CSS poniżej 81% szans na spłatę (Ventyle 0-16 są stratne) */
    _cutoff_ins = 0.90; /* Odrzucamy INS poniżej 90% szans na spłatę (Minimalizacja straty) */


    /* --- LOGIKA BIZNESOWA --- */

    /* 1. Sprawdzenie czy klient jest aktywny */
    if active_customer_flag = 0 then do;
        decision = 'DECLINE';
        rejection_reason = '998: Not active customer';
        cross_sell_offer = 0; 
    end;
    
    else do;
        /* =========================================================
           PRODUKT INS (Raty)
           Strategia: Minimalizacja strat + Ochrona przed kosztami stałymi
           ========================================================= */
        if _prod_norm = 'ins' then do;
            
            /* Reguła Biznesowa: Kwota minimalna (koszty stałe) */
            if app_loan_amount < 3000 then do;
                decision = 'DECLINE';
                rejection_reason = 'Biz: Low Amount (<3k)';
            end;

            /* Reguła Biznesowa: Minimalna liczba rat */
            else if app_n_installments < 10 then do;
                decision = 'DECLINE';
                rejection_reason = 'Biz: Short Tenor (<10)';
            end;
            
            /* Reguła Ryzyka (POPRAWIONA LOGIKA):
               Wcześniej: if SCORE > 0.09 (zakładając że to default).
               Teraz: Akceptujemy tylko "Grube Ryby" z wysokim prawdopodobieństwem spłaty.
               Używamy zmiennej PD_css_scorecard jako głównego wskaźnika (potwierdzone w teście). */
            else if PD_css_scorecard < _cutoff_ins then do; 
                decision = 'DECLINE';
                rejection_reason = 'Risk: Low Score INS';
            end;
        end;

        /* =========================================================
           PRODUKT CSS (Gotówka)
           Strategia: Eliminacja toksycznego portfela (Ventyle 0-16)
           ========================================================= */
        else if _prod_norm = 'css' then do;
            
            if missing(PD_css_scorecard) then do;
                decision = 'MANUAL';
                rejection_reason = 'ERR: Missing Score CSS';
            end;
            
            else do;
                /* Logika uproszczona (bo wszystkie kwoty to 5000 PLN).
                   Jeśli pojawią się inne kwoty, kod zadziała bezpiecznie (wytnie ryzyko).
                   
                   WAŻNE: Znak nierówności "<". 
                   Odrzucamy, jeśli Prawdopodobieństwo Spłaty jest MAŁE. */
                   
                if PD_css_scorecard < _cutoff_css then do;
                    decision = 'DECLINE';
                    rejection_reason = 'Risk: CSS Low Quality';
                end;
            end;
        end;
        
        else do;
            decision = 'ERROR';
            rejection_reason = cat('Unknown Product Type: ', product);
        end;

        /* =========================================================
           CROSS-SELL
           Strategia: Oferuj tylko klientom "dobrym" i "chętnym"
           ========================================================= */
        if cross_sell_offer = 1 then do;
            /* Ryzyko: Jeśli szansa na spłatę (prob_default...) jest niska, nie oferuj */
            /* Uwaga: prob_default_css_cross też jest skalowane jako "Good" w tym modelu */
            if prob_default_css_cross < _cutoff_css then cross_sell_offer = 0; 
            
            /* Responsywność: Jeśli szansa na zakup niska, nie oferuj */
            if prob_response_css < 0.015 then cross_sell_offer = 0;
        end;

    end;
    
    /* Sprzątanie zmiennych tymczasowych */
    drop _prod_norm _cutoff_css _cutoff_ins;
run;

/* --- RAPORTOWANIE WYNIKÓW --- */
title "Podsumowanie Nowej Strategii Decyzyjnej (Logika: High Score = Good)";

proc freq data=out.abt_scored_final;
    tables decision rejection_reason cross_sell_offer product*decision / list missing;
run;

/* Sprawdzenie średniego PD (Score) w grupach zaakceptowanych i odrzuconych,
   aby upewnić się, że akceptujemy tych z WYSOKIM wynikiem */
proc means data=out.abt_scored_final mean min max;
    class product decision;
    var PD_css_scorecard;
run;

title;