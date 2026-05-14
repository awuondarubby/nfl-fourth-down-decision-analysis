/*===============================================================
  Exam 2 Take-Home Project
  NFL 4th Down Decision Modeling
  Student: Awuonda Rubby
  Purpose: Predict whether teams go for it or kick on 4th down
================================================================*/
proc printto log="/home/u64427608/PG1/Assignments/rubby_awuonda_exam2.log" new;
run;
/* Step 1: Import the data */

proc import datafile="/home/u64427608/PG1/Assignments/play_by_play_2025.csv"
    out=work.pbp_2025
    dbms=csv
    replace;
    guessingrows=max;
run;


/* Step 2: Filter to assigned teams and 4th down plays */

data work.fourth_down_clean;
    set work.pbp_2025;

    where posteam in ('ATL', 'BAL', 'BUF', 'CIN', 'CLE', 'DAL', 'DEN', 'GB',
                      'IND', 'KC', 'LA', 'MIA', 'MIN', 'NE', 'NYJ', 'PHI',
                      'PIT', 'SEA', 'SF', 'TB')
          and down = 4;
run;


/* Check filtered dataset */

proc contents data=work.fourth_down_clean;
run;

proc print data=work.fourth_down_clean(obs=10);
    var posteam down play_type qtr ydstogo yardline_100 score_differential;
run;

proc freq data=work.fourth_down_clean;
    tables posteam;
run;


/* Step 3: Create response variable */

data work.fourth_down_model;
    set work.fourth_down_clean;

    if play_type in ('run', 'pass') then go_for_it = 1;
    else if play_type in ('punt', 'field_goal') then go_for_it = 0;
    else go_for_it = .;
run;


/* Remove unclear decisions */

data work.fourth_down_model;
    set work.fourth_down_model;

    if go_for_it = . then delete;
run;


/* Create format for response variable */

proc format;
    value gofmt
        0 = 'Kick'
        1 = 'Go For It';
run;


/* Frequency of response */

proc freq data=work.fourth_down_model;
    tables go_for_it;
    format go_for_it gofmt.;
run;


/* Step 4: Missing values and predictor summaries */

proc means data=work.fourth_down_model n nmiss mean std min max;
    var ydstogo yardline_100 score_differential game_seconds_remaining
        half_seconds_remaining posteam_timeouts_remaining
        defteam_timeouts_remaining;
run;

proc freq data=work.fourth_down_model;
    tables qtr;
run;


/* Step 5: Create categorical bins for EDA */

data work.fourth_down_model;
    set work.fourth_down_model;

    length ydstogo_bin $10;
    length score_bin $15;
    length field_bin $20;

    if ydstogo <= 2 then ydstogo_bin = "Short";
    else if ydstogo <= 5 then ydstogo_bin = "Medium";
    else ydstogo_bin = "Long";

    if score_differential < -7 then score_bin = "Trailing";
    else if score_differential <= 7 then score_bin = "Close";
    else score_bin = "Leading";

    if yardline_100 <= 35 then field_bin = "Scoring Range";
    else if yardline_100 <= 65 then field_bin = "Midfield";
    else field_bin = "Own Territory";
run;


/* Step 6: Cross tabulations with Chi Square and Cramer's V */

proc freq data=work.fourth_down_model;
    tables go_for_it*qtr / chisq measures;
    format go_for_it gofmt.;
run;

proc freq data=work.fourth_down_model;
    tables go_for_it*ydstogo_bin / chisq measures;
    format go_for_it gofmt.;
run;

proc freq data=work.fourth_down_model;
    tables go_for_it*score_bin / chisq measures;
    format go_for_it gofmt.;
run;

proc freq data=work.fourth_down_model;
    tables go_for_it*field_bin / chisq measures;
    format go_for_it gofmt.;
run;


/* Step 7: Odds ratio example for short yardage */

data work.odds_model;
    set work.fourth_down_model;

    length short_yardage $3;

    if ydstogo <= 2 then short_yardage = "Yes";
    else short_yardage = "No";
run;

proc freq data=work.odds_model;
    tables short_yardage*go_for_it / chisq relrisk;
    format go_for_it gofmt.;
run;


/* Step 8: Visualization */

proc sgplot data=work.fourth_down_model;
    vbar ydstogo_bin / group=go_for_it groupdisplay=cluster stat=percent;
    format go_for_it gofmt.;
    title "Fourth Down Decision by Yards to Go Category";
    xaxis label="Yards to Go Category";
    yaxis label="Percent of Plays";
run;


/* Step 9: Initial Logistic Regression Model */

proc logistic data=work.fourth_down_model plots=roc;
    class qtr (param=ref ref='1');

    model go_for_it(event='1') =
        qtr
        ydstogo
        yardline_100
        score_differential
        game_seconds_remaining
        posteam_timeouts_remaining
        defteam_timeouts_remaining
    / ctable pprob=0.5 lackfit clodds=pl;

    oddsratio qtr;
    oddsratio ydstogo;
    oddsratio yardline_100;
    oddsratio score_differential;
    oddsratio game_seconds_remaining;
    oddsratio posteam_timeouts_remaining;
    oddsratio defteam_timeouts_remaining;

    title "Initial Logistic Regression Model for Fourth Down Decisions";
run;


/* Step 10: Stepwise Logistic Regression Model */

proc logistic data=work.fourth_down_model plots=roc;
    class qtr (param=ref ref='1');

    model go_for_it(event='1') =
        qtr
        ydstogo
        yardline_100
        score_differential
        game_seconds_remaining
        posteam_timeouts_remaining
        defteam_timeouts_remaining
    / selection=stepwise
      slentry=0.05
      slstay=0.05
      ctable pprob=0.5
      lackfit
      clodds=pl;

    oddsratio qtr;
    oddsratio ydstogo;
    oddsratio yardline_100;
    oddsratio score_differential;
    oddsratio game_seconds_remaining;
    oddsratio posteam_timeouts_remaining;
    oddsratio defteam_timeouts_remaining;

    title "Stepwise Logistic Regression Model for Fourth Down Decisions";
run;

proc printto;
run;

/* End of program */