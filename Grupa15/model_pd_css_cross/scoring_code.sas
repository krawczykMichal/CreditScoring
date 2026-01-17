data inlib.out;
    set out.abt_app;
    SCORECARD_POINTS = 0;

    /* ACT12_N_GOOD_DAYS */
    select;
        when ( missing(ACT12_N_GOOD_DAYS) ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,54);
            PSC_ACT12_N_GOOD_DAYS=54;
        end;
        when ( not missing(ACT12_N_GOOD_DAYS) and ACT12_N_GOOD_DAYS <= 2 ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,45);
            PSC_ACT12_N_GOOD_DAYS=45;
        end;
        when ( 2 < ACT12_N_GOOD_DAYS <= 3 ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,37);
            PSC_ACT12_N_GOOD_DAYS=37;
        end;
        when ( 8 < ACT12_N_GOOD_DAYS ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,34);
            PSC_ACT12_N_GOOD_DAYS=34;
        end;
        when ( 3 < ACT12_N_GOOD_DAYS <= 4 ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,34);
            PSC_ACT12_N_GOOD_DAYS=34;
        end;
        when ( 4 < ACT12_N_GOOD_DAYS <= 8 ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,29);
            PSC_ACT12_N_GOOD_DAYS=29;
        end;
        otherwise do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,29);
            PSC_ACT12_N_GOOD_DAYS=29;
        end;
    end;

    /* ACT_CCSS_MAXDUE */
    select;
        when ( missing(ACT_CCSS_MAXDUE) ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,71);
            PSC_ACT_CCSS_MAXDUE=71;
        end;
        when ( not missing(ACT_CCSS_MAXDUE) and ACT_CCSS_MAXDUE <= 0 ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,59);
            PSC_ACT_CCSS_MAXDUE=59;
        end;
        when ( 0 < ACT_CCSS_MAXDUE <= 1 ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,45);
            PSC_ACT_CCSS_MAXDUE=45;
        end;
        when ( 4 < ACT_CCSS_MAXDUE ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,37);
            PSC_ACT_CCSS_MAXDUE=37;
        end;
        when ( 1 < ACT_CCSS_MAXDUE <= 4 ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,29);
            PSC_ACT_CCSS_MAXDUE=29;
        end;
        otherwise do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,29);
            PSC_ACT_CCSS_MAXDUE=29;
        end;
    end;

    /* ACT_CCSS_N_STATC */
    select;
        when ( 26 < ACT_CCSS_N_STATC ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,125);
            PSC_ACT_CCSS_N_STATC=125;
        end;
        when ( 15 < ACT_CCSS_N_STATC <= 26 ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,85);
            PSC_ACT_CCSS_N_STATC=85;
        end;
        when ( missing(ACT_CCSS_N_STATC) ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,79);
            PSC_ACT_CCSS_N_STATC=79;
        end;
        when ( 6 < ACT_CCSS_N_STATC <= 15 ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,54);
            PSC_ACT_CCSS_N_STATC=54;
        end;
        when ( 4 < ACT_CCSS_N_STATC <= 6 ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,40);
            PSC_ACT_CCSS_N_STATC=40;
        end;
        when ( not missing(ACT_CCSS_N_STATC) and ACT_CCSS_N_STATC <= 4 ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,29);
            PSC_ACT_CCSS_N_STATC=29;
        end;
        otherwise do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,29);
            PSC_ACT_CCSS_N_STATC=29;
        end;
    end;

    /* ACT_CCSS_UTL */
    select;
        when ( 0.5347222222 < ACT_CCSS_UTL ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,58);
            PSC_ACT_CCSS_UTL=58;
        end;
        when ( missing(ACT_CCSS_UTL) ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,57);
            PSC_ACT_CCSS_UTL=57;
        end;
        when ( 0.5208333333 < ACT_CCSS_UTL <= 0.5347222222 ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,44);
            PSC_ACT_CCSS_UTL=44;
        end;
        when ( 0.4895833333 < ACT_CCSS_UTL <= 0.5208333333 ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,40);
            PSC_ACT_CCSS_UTL=40;
        end;
        when ( 0.4479166667 < ACT_CCSS_UTL <= 0.4895833333 ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,36);
            PSC_ACT_CCSS_UTL=36;
        end;
        when ( 0.4083333333 < ACT_CCSS_UTL <= 0.4479166667 ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,32);
            PSC_ACT_CCSS_UTL=32;
        end;
        when ( not missing(ACT_CCSS_UTL) and ACT_CCSS_UTL <= 0.4083333333 ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,29);
            PSC_ACT_CCSS_UTL=29;
        end;
        otherwise do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,29);
            PSC_ACT_CCSS_UTL=29;
        end;
    end;

    /* AGS3_MEAN_CMAXA_DUE */
    select;
        when ( missing(AGS3_MEAN_CMAXA_DUE) ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,60);
            PSC_AGS3_MEAN_CMAXA_DUE=60;
        end;
        when ( not missing(AGS3_MEAN_CMAXA_DUE) and AGS3_MEAN_CMAXA_DUE <= 0.6666666667 ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,49);
            PSC_AGS3_MEAN_CMAXA_DUE=49;
        end;
        when ( 0.6666666667 < AGS3_MEAN_CMAXA_DUE <= 1 ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,39);
            PSC_AGS3_MEAN_CMAXA_DUE=39;
        end;
        when ( 3 < AGS3_MEAN_CMAXA_DUE ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,33);
            PSC_AGS3_MEAN_CMAXA_DUE=33;
        end;
        when ( 1 < AGS3_MEAN_CMAXA_DUE <= 3 ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,29);
            PSC_AGS3_MEAN_CMAXA_DUE=29;
        end;
        otherwise do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,29);
            PSC_AGS3_MEAN_CMAXA_DUE=29;
        end;
    end;

    /* APP_INCOME */
    select;
        when ( 1049 < APP_INCOME <= 3872 ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,77);
            PSC_APP_INCOME=77;
        end;
        when ( 573 < APP_INCOME <= 1049 ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,60);
            PSC_APP_INCOME=60;
        end;
        when ( 3872 < APP_INCOME ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,52);
            PSC_APP_INCOME=52;
        end;
        when ( 411 < APP_INCOME <= 573 ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,42);
            PSC_APP_INCOME=42;
        end;
        when ( not missing(APP_INCOME) and APP_INCOME <= 411 ) do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,29);
            PSC_APP_INCOME=29;
        end;
        otherwise do;
            SCORECARD_POINTS=sum(SCORECARD_POINTS,29);
            PSC_APP_INCOME=29;
        end;
    end;
run;

/* 2. KROK KALIBRACJI PD */
data out.abt_app;
    set inlib.out; /* Poprawka: czytamy z tabeli utworzonej wyżej */
    
    /* Wzór przeliczający punkty na PD (0-1) */
    /* Upewnij się, że współczynniki (-0.0289... i 8.249...) są poprawne dla Twojego modelu */
    prob_default_css_cross = 1 / (1 + exp( -(-0.028954669 * SCORECARD_POINTS + 8.2497434934) ));
    
    /* Usuwamy zmienne tymczasowe PSC_ i punkty (jeśli niepotrzebne) */
    /* Uwaga: dwukropek 'psc:' usuwa wszystkie zmienne zaczynające się od psc */
    drop psc:; 
    /* Jeśli chcesz zostawić SCORECARD_POINTS do analizy, usuń go z listy drop */
run;
