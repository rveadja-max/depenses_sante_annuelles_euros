/**********************************************************************
 * Programme SAS : Analyse statistique de l'état de santé perçu
 * ------------------------------------------------------------------
 * Reproduction intégrale des analyses réalisées sous R (rapport.Rmd)
 * dans l'environnement SAS.
 *
 * Auteur  : Hervé ADJAKOSSA
 * Module  : Modèles linéaires – Statistical Analysis System
 * Données : base_esps_synthétique.csv  (500 obs. × 25 variables)
 *
 * Le fichier doit être exécuté dans SAS (SAS OnDemand, SAS 9.4
 * ou SAS Viya). Adapter le chemin %LET ci-dessous.
 **********************************************************************/

/* ================================================================== */
/*  0.  PARAMÉTRAGE GLOBAL                                            */
/* ================================================================== */

/* -- Adapter ce chemin au répertoire contenant le fichier CSV ------- */
%LET chemin = /home/u00000000/depenses_sante_annuelles_euros/data;

/* -- Options globales ---------------------------------------------- */
OPTIONS NOCENTER PAGESIZE=MAX LINESIZE=MAX FORMCHAR="|----|+|---+=|-/\<>*"
        FMTSEARCH=(WORK);

ODS GRAPHICS ON;                       /* Active les graphiques ODS   */
TITLE "Analyse statistique de l'état de santé perçu en France";

/* ================================================================== */
/*  1.  IMPORTATION DE LA BASE DE DONNÉES                             */
/* ================================================================== */
/*  Le CSV utilise « ; » comme séparateur de champ et « . » comme     */
/*  séparateur décimal. L'encodage est UTF-8.                         */
/* ================================================================== */

PROC IMPORT DATAFILE="&chemin./base_esps_synthétique.csv"
            OUT=WORK.esps
            DBMS=CSV REPLACE;
    DELIMITER=";";
    GETNAMES=YES;
    GUESSINGROWS=500;
    DATAROW=2;
RUN;

/* Vérification rapide */
PROC CONTENTS DATA=esps VARNUM; RUN;
PROC PRINT DATA=esps (OBS=5); RUN;

TITLE2 "Dimensions de la base";
PROC SQL;
    SELECT COUNT(*) AS nb_observations,
           COUNT(*) AS nb_variables
           FORMAT=COMMA8.
    FROM DICTIONARY.COLUMNS
    WHERE LIBNAME='WORK' AND MEMNAME='ESPS';
QUIT;

/* ================================================================== */
/*  2.  CONSTRUCTION DES VARIABLES DÉRIVÉES                           */
/* ================================================================== */
/*  - score_sante : 1 (Très mauvais) → 5 (Très bon)                  */
/*  - sante_mauvaise : 0/1 (bonne/mauvaise santé)                     */
/*  - Variables numériques binaires                                    */
/* ================================================================== */

DATA esps;
    SET esps;

    /* Score ordinal (1 = Très mauvais → 5 = Très bon) */
    SELECT (etat_sante_percu);
        WHEN ("Très mauvais") score_sante = 1;
        WHEN ("Mauvais")      score_sante = 2;
        WHEN ("Assez bon")    score_sante = 3;
        WHEN ("Bon")          score_sante = 4;
        WHEN ("Très bon")     score_sante = 5;
        OTHERWISE             score_sante = .;
    END;

    /* Variable binaire : 0 = Bonne santé, 1 = Mauvaise santé */
    IF score_sante IN (1, 2) THEN sante_mauvaise = 1;
    ELSE IF score_sante NE . THEN sante_mauvaise = 0;

    /* Recodages numériques pour les variables binaires */
    hospit_num      = (hospitalisation_12_mois = "Oui");
    handicap_num    = (handicap_declare = "Oui");
    renoncement_num = (renoncement_soins_12_mois = "Oui");
RUN;

/* Vérification du recodage */
TITLE2 "Vérification du recodage ordinal";
PROC FREQ DATA=esps;
    TABLES etat_sante_percu * score_sante / NOCOL NOROW NOPERCENT;
RUN;

/* Distribution de la variable réponse */
TITLE2 "Distribution de la variable réponse — État de santé perçu";
PROC FREQ DATA=esps ORDER=DATA;
    TABLES etat_sante_percu / PLOTS=FREQPLOT;
RUN;


/* ================================================================== */
/*  3.  STATISTIQUES DESCRIPTIVES                                     */
/* ================================================================== */

TITLE2 "Statistiques descriptives — Variables quantitatives";
PROC MEANS DATA=esps N MEAN STD MIN Q1 MEDIAN Q3 MAX;
    VAR age revenus_mensuels_euros imc
        depenses_sante_annuelles_euros
        nombre_consultations_annuelles
        nombre_medicaments_reguliers
        nombre_enfants score_sante;
RUN;

TITLE2 "Statistiques descriptives — Variables qualitatives";
PROC FREQ DATA=esps;
    TABLES sexe profession niveau_education situation_familiale
           couverture_complementaire hospitalisation_12_mois
           tabagisme consommation_alcool activite_physique
           handicap_declare renoncement_soins_12_mois
           maladies_declarees satisfaction_systeme_soins
           region type_commune statut_assurance;
RUN;


/* ================================================================== */
/*  4.  ANALYSE BIVARIÉE                                              */
/* ================================================================== */

/* ------------------------------------------------------------------ */
/*  4.1  Tests du Chi-2 : Y qualitative × X qualitatives              */
/* ------------------------------------------------------------------ */

TITLE2 "4.1 — Tests du Chi-2 : État de santé perçu × Variables qualitatives";

%MACRO chi2(var, label);
    TITLE3 "Chi-2 : État de santé perçu × &label";
    PROC FREQ DATA=esps;
        TABLES etat_sante_percu * &var / CHISQ EXPECTED
               PLOTS=FREQPLOT(TWOWAY=STACKED);
    RUN;
%MEND;

%chi2(sexe,                       Sexe);
%chi2(profession,                 Profession);
%chi2(niveau_education,           Niveau d'éducation);
%chi2(situation_familiale,        Situation familiale);
%chi2(couverture_complementaire,  Couverture complémentaire);
%chi2(hospitalisation_12_mois,    Hospitalisation 12 mois);
%chi2(tabagisme,                  Tabagisme);
%chi2(consommation_alcool,        Consommation d'alcool);
%chi2(activite_physique,          Activité physique);
%chi2(handicap_declare,           Handicap déclaré);
%chi2(renoncement_soins_12_mois,  Renoncement aux soins 12 mois);
%chi2(maladies_declarees,         Maladies déclarées);


/* ------------------------------------------------------------------ */
/*  4.2  ANOVA à un facteur : Y qualitative × X quantitatives         */
/* ------------------------------------------------------------------ */

TITLE2 "4.2 — ANOVA : Variables quantitatives selon l'état de santé perçu";

%MACRO anova_biv(var, label);
    TITLE3 "ANOVA : &label selon l'état de santé perçu";
    PROC GLM DATA=esps PLOTS=DIAGNOSTICS;
        CLASS etat_sante_percu;
        MODEL &var = etat_sante_percu;
        MEANS etat_sante_percu / TUKEY CLDIFF;
    QUIT;
%MEND;

%anova_biv(age,                              Âge);
%anova_biv(revenus_mensuels_euros,           Revenus mensuels);
%anova_biv(imc,                              IMC);
%anova_biv(depenses_sante_annuelles_euros,   Dépenses de santé annuelles);
%anova_biv(nombre_consultations_annuelles,   Nombre de consultations annuelles);
%anova_biv(nombre_medicaments_reguliers,     Nombre de médicaments réguliers);


/* ------------------------------------------------------------------ */
/*  4.3  Test de Kruskal-Wallis (alternative non paramétrique)         */
/* ------------------------------------------------------------------ */

TITLE2 "4.3 — Tests de Kruskal-Wallis";

%MACRO kruskal(var, label);
    TITLE3 "Kruskal-Wallis : &label selon l'état de santé perçu";
    PROC NPAR1WAY DATA=esps WILCOXON;
        CLASS etat_sante_percu;
        VAR &var;
    RUN;
%MEND;

%kruskal(age,                              Âge);
%kruskal(revenus_mensuels_euros,           Revenus mensuels);
%kruskal(imc,                              IMC);
%kruskal(depenses_sante_annuelles_euros,   Dépenses de santé annuelles);
%kruskal(nombre_consultations_annuelles,   Nombre de consultations annuelles);
%kruskal(nombre_medicaments_reguliers,     Nombre de médicaments réguliers);


/* ------------------------------------------------------------------ */
/*  4.4  Corrélation de Spearman                                       */
/* ------------------------------------------------------------------ */

TITLE2 "4.4 — Corrélation de Spearman : score_sante vs variables quantitatives";
PROC CORR DATA=esps SPEARMAN NOSIMPLE;
    VAR score_sante;
    WITH age revenus_mensuels_euros imc
         depenses_sante_annuelles_euros
         nombre_consultations_annuelles
         nombre_medicaments_reguliers
         nombre_enfants;
RUN;


/* ------------------------------------------------------------------ */
/*  4.5  Boîtes à moustaches                                          */
/* ------------------------------------------------------------------ */

TITLE2 "4.5 — Boîtes à moustaches";

%MACRO boxplot(var, label);
    TITLE3 "Boxplot : &label selon l'état de santé perçu";
    PROC SGPLOT DATA=esps;
        VBOX &var / CATEGORY=etat_sante_percu;
        XAXIS LABEL="État de santé perçu";
        YAXIS LABEL="&label";
    RUN;
%MEND;

%boxplot(age,                              Âge);
%boxplot(revenus_mensuels_euros,           Revenus mensuels (€));
%boxplot(imc,                              IMC);
%boxplot(depenses_sante_annuelles_euros,   Dépenses de santé annuelles (€));
%boxplot(nombre_consultations_annuelles,   Nombre de consultations annuelles);
%boxplot(nombre_medicaments_reguliers,     Nombre de médicaments réguliers);


/* ================================================================== */
/*  5.  MATRICE DE CORRÉLATION DES VARIABLES QUANTITATIVES             */
/* ================================================================== */

TITLE2 "5 — Matrice de corrélation (Pearson et Spearman)";
PROC CORR DATA=esps PEARSON SPEARMAN PLOTS=MATRIX(NVAR=ALL);
    VAR age revenus_mensuels_euros imc
        depenses_sante_annuelles_euros
        nombre_consultations_annuelles
        nombre_medicaments_reguliers
        nombre_enfants;
RUN;


/* ================================================================== */
/*  6.  RÉGRESSION LINÉAIRE MULTIPLE ET R²                             */
/* ================================================================== */

/* ------------------------------------------------------------------ */
/*  6.1  Modèle complet — variables quantitatives                      */
/* ------------------------------------------------------------------ */

TITLE2 "6.1 — Régression linéaire : Modèle complet (7 variables quantitatives)";
PROC REG DATA=esps PLOTS=(DIAGNOSTICS RESIDUALS COOKSD RSTUDENTBYLEV);
    MODEL score_sante = age revenus_mensuels_euros
                        depenses_sante_annuelles_euros
                        nombre_consultations_annuelles
                        nombre_medicaments_reguliers
                        imc nombre_enfants
                        / VIF TOL COLLIN INFLUENCE R SPEC DW;
    OUTPUT OUT=resid_complet
           PREDICTED=yhat_complet
           RESIDUAL=resid_comp
           RSTUDENT=rstud_comp
           COOKD=cook_comp
           H=leverage_comp;
    TITLE3 "Modèle complet";
QUIT;

/* ------------------------------------------------------------------ */
/*  6.2  Modèle réduit — variables significatives                      */
/* ------------------------------------------------------------------ */

TITLE2 "6.2 — Régression linéaire : Modèle réduit (age, consultations, médicaments)";
PROC REG DATA=esps PLOTS=(DIAGNOSTICS RESIDUALS COOKSD RSTUDENTBYLEV);
    MODEL score_sante = age
                        nombre_consultations_annuelles
                        nombre_medicaments_reguliers
                        / VIF TOL COLLIN INFLUENCE R SPEC DW;
    OUTPUT OUT=resid_reduit
           PREDICTED=yhat_red
           RESIDUAL=resid_red
           RSTUDENT=rstud_red
           COOKD=cook_red
           H=leverage_red;
    TITLE3 "Modèle réduit";
QUIT;

/* ------------------------------------------------------------------ */
/*  6.3  Test F emboîté : modèle réduit vs modèle complet             */
/* ------------------------------------------------------------------ */

TITLE2 "6.3 — Comparaison : modèle réduit vs modèle complet (Test F emboîté)";
PROC REG DATA=esps;
    mod_complet: MODEL score_sante = age revenus_mensuels_euros
                        depenses_sante_annuelles_euros
                        nombre_consultations_annuelles
                        nombre_medicaments_reguliers
                        imc nombre_enfants;
    mod_reduit:  MODEL score_sante = age
                        nombre_consultations_annuelles
                        nombre_medicaments_reguliers;
    /* Le test F de comparaison s'obtient en examinant les R² et SSE  */
    /* des deux modèles dans la sortie.                                */
QUIT;

/* Test explicite via PROC GLM avec CONTRAST ou TEST statement :      */
PROC GLM DATA=esps;
    MODEL score_sante = age revenus_mensuels_euros
                        depenses_sante_annuelles_euros
                        nombre_consultations_annuelles
                        nombre_medicaments_reguliers
                        imc nombre_enfants / SS3;
    /* Test conjoint que les 4 variables exclues sont nulles */
    TEST revenus_mensuels_euros, depenses_sante_annuelles_euros,
         imc, nombre_enfants;
QUIT;


/* ================================================================== */
/*  7.  ÉTUDE DE LA COLINÉARITÉ                                        */
/* ================================================================== */

/* Les VIF, tolérance et indices de conditionnement sont produits      */
/* par les options VIF TOL COLLIN de PROC REG ci-dessus (section 6).  */
/* Les résultats figurent déjà dans la sortie de la section 6.1.      */

TITLE2 "7 — Colinéarité : VIF, tolérance, indices de conditionnement";
PROC REG DATA=esps;
    MODEL score_sante = age revenus_mensuels_euros
                        depenses_sante_annuelles_euros
                        nombre_consultations_annuelles
                        nombre_medicaments_reguliers
                        imc nombre_enfants
                        / VIF TOL COLLIN COLLINOINT;
QUIT;


/* ================================================================== */
/*  8.  SÉLECTION DE VARIABLES                                         */
/* ================================================================== */

/* ------------------------------------------------------------------ */
/*  8.1  Sélection exhaustive (PROC REG avec SELECTION=RSQUARE/CP)     */
/*       → Équivalent de leaps::regsubsets sous R                      */
/* ------------------------------------------------------------------ */

TITLE2 "8.1 — Sélection exhaustive : R² ajusté, BIC, Cp de Mallows";

PROC REG DATA=esps;
    MODEL score_sante = age revenus_mensuels_euros
                        depenses_sante_annuelles_euros
                        nombre_consultations_annuelles
                        nombre_medicaments_reguliers
                        imc nombre_enfants
                        / SELECTION=RSQUARE ADJRSQ CP BIC BEST=5;
    TITLE3 "Meilleurs sous-modèles (R², Cp, BIC)";
QUIT;

/* ------------------------------------------------------------------ */
/*  8.2  Sélection ascendante (Forward)                                */
/* ------------------------------------------------------------------ */

TITLE2 "8.2 — Sélection Forward (SLE=0.05)";
PROC REG DATA=esps;
    MODEL score_sante = age revenus_mensuels_euros
                        depenses_sante_annuelles_euros
                        nombre_consultations_annuelles
                        nombre_medicaments_reguliers
                        imc nombre_enfants
                        / SELECTION=FORWARD SLE=0.05;
QUIT;

/* ------------------------------------------------------------------ */
/*  8.3  Sélection descendante (Backward)                              */
/* ------------------------------------------------------------------ */

TITLE2 "8.3 — Sélection Backward (SLS=0.05)";
PROC REG DATA=esps;
    MODEL score_sante = age revenus_mensuels_euros
                        depenses_sante_annuelles_euros
                        nombre_consultations_annuelles
                        nombre_medicaments_reguliers
                        imc nombre_enfants
                        / SELECTION=BACKWARD SLS=0.05;
QUIT;

/* ------------------------------------------------------------------ */
/*  8.4  Sélection pas à pas (Stepwise)                                */
/* ------------------------------------------------------------------ */

TITLE2 "8.4 — Sélection Stepwise (SLE=0.05, SLS=0.05)";
PROC REG DATA=esps;
    MODEL score_sante = age revenus_mensuels_euros
                        depenses_sante_annuelles_euros
                        nombre_consultations_annuelles
                        nombre_medicaments_reguliers
                        imc nombre_enfants
                        / SELECTION=STEPWISE SLE=0.05 SLS=0.05;
QUIT;


/* ================================================================== */
/*  9.  VALIDATION DU MODÈLE RETENU                                    */
/* ================================================================== */
/*  Modèle retenu : score_sante = age + consultations + médicaments    */
/* ================================================================== */

TITLE2 "9 — Validation du modèle retenu";

/* ------------------------------------------------------------------ */
/*  9.1  Régression avec diagnostics complets                          */
/*       VIF, Durbin-Watson, test de White (SPEC), Cook, Leverage      */
/* ------------------------------------------------------------------ */

PROC REG DATA=esps
         PLOTS=(DIAGNOSTICS(STATS=ALL)
                RESIDUALS(SMOOTH)
                COOKSD(LABEL)
                RSTUDENTBYLEV(LABEL)
                QQPLOT
                RESIDUALBYPREDICTED);
    MODEL score_sante = age
                        nombre_consultations_annuelles
                        nombre_medicaments_reguliers
                        / VIF TOL SPEC DW INFLUENCE R COLLIN;
    OUTPUT OUT=valid_out
           PREDICTED=yhat RESIDUAL=resid
           RSTUDENT=rstud COOKD=cook H=leverage;
    TITLE3 "Diagnostics complets du modèle retenu";
QUIT;

/* ------------------------------------------------------------------ */
/*  9.2  Test de normalité des résidus (Shapiro-Wilk)                  */
/* ------------------------------------------------------------------ */

TITLE2 "9.2 — Normalité des résidus (Shapiro-Wilk)";
PROC UNIVARIATE DATA=valid_out NORMAL PLOTS;
    VAR resid;
    QQPLOT resid / NORMAL(MU=EST SIGMA=EST);
    HISTOGRAM resid / NORMAL;
RUN;

/* ------------------------------------------------------------------ */
/*  9.3  Histogramme des résidus                                       */
/* ------------------------------------------------------------------ */

TITLE2 "9.3 — Histogramme des résidus";
PROC SGPLOT DATA=valid_out;
    HISTOGRAM resid / FILLATTRS=(COLOR=steelblue TRANSPARENCY=0.3);
    DENSITY resid / TYPE=NORMAL LINEATTRS=(COLOR=red THICKNESS=2);
    XAXIS LABEL="Résidu";
    YAXIS LABEL="Densité";
RUN;

/* ------------------------------------------------------------------ */
/*  9.4  Résidus vs valeurs ajustées (linéarité)                       */
/* ------------------------------------------------------------------ */

TITLE2 "9.4 — Résidus vs valeurs ajustées (linéarité)";
PROC SGPLOT DATA=valid_out;
    SCATTER X=yhat Y=resid / MARKERATTRS=(SIZE=4 SYMBOL=CIRCLEFILLED)
            TRANSPARENCY=0.5;
    LOESS X=yhat Y=resid / LINEATTRS=(COLOR=red THICKNESS=2);
    REFLINE 0 / AXIS=Y LINEATTRS=(PATTERN=DASH);
    XAXIS LABEL="Valeurs ajustées (ŷ)";
    YAXIS LABEL="Résidus";
RUN;

/* ------------------------------------------------------------------ */
/*  9.5  RStudent vs Leverage                                          */
/* ------------------------------------------------------------------ */

TITLE2 "9.5 — RStudent vs Leverage";
PROC SGPLOT DATA=valid_out;
    SCATTER X=leverage Y=rstud /
            MARKERATTRS=(SIZE=4 SYMBOL=CIRCLEFILLED) TRANSPARENCY=0.5;
    REFLINE -2 2  / AXIS=Y LINEATTRS=(PATTERN=DASH COLOR=red);
    REFLINE %SYSEVALF(2*4/500) / AXIS=X LINEATTRS=(PATTERN=DASH COLOR=blue);
    XAXIS LABEL="Leverage (h_ii)";
    YAXIS LABEL="RStudent";
RUN;

/* ------------------------------------------------------------------ */
/*  9.6  Distance de Cook                                              */
/* ------------------------------------------------------------------ */

TITLE2 "9.6 — Distance de Cook";
PROC SGPLOT DATA=valid_out;
    NEEDLE X=id Y=cook / LINEATTRS=(COLOR=steelblue);
    REFLINE %SYSEVALF(4/500) / AXIS=Y LINEATTRS=(PATTERN=DASH COLOR=red);
    XAXIS LABEL="Observation";
    YAXIS LABEL="Distance de Cook";
RUN;

/* ------------------------------------------------------------------ */
/*  9.7  LOESS : score_sante vs chaque prédicteur                      */
/* ------------------------------------------------------------------ */

TITLE2 "9.7 — Lissage LOESS";

PROC SGPLOT DATA=esps;
    SCATTER X=age Y=score_sante / TRANSPARENCY=0.7;
    LOESS X=age Y=score_sante / LINEATTRS=(COLOR=red THICKNESS=2);
    XAXIS LABEL="Âge"; YAXIS LABEL="Score santé";
    TITLE3 "LOESS : Score santé vs Âge";
RUN;

PROC SGPLOT DATA=esps;
    SCATTER X=nombre_consultations_annuelles Y=score_sante / TRANSPARENCY=0.7;
    LOESS X=nombre_consultations_annuelles Y=score_sante /
          LINEATTRS=(COLOR=red THICKNESS=2);
    XAXIS LABEL="Consultations annuelles"; YAXIS LABEL="Score santé";
    TITLE3 "LOESS : Score santé vs Consultations";
RUN;

PROC SGPLOT DATA=esps;
    SCATTER X=nombre_medicaments_reguliers Y=score_sante / TRANSPARENCY=0.7;
    LOESS X=nombre_medicaments_reguliers Y=score_sante /
          LINEATTRS=(COLOR=red THICKNESS=2);
    XAXIS LABEL="Médicaments réguliers"; YAXIS LABEL="Score santé";
    TITLE3 "LOESS : Score santé vs Médicaments";
RUN;

/* ------------------------------------------------------------------ */
/*  9.8  Observations potentiellement aberrantes / influentes          */
/* ------------------------------------------------------------------ */

TITLE2 "9.8 — Observations potentiellement aberrantes / influentes";
PROC PRINT DATA=valid_out NOOBS;
    WHERE ABS(rstud) > 2 OR cook > (4/500);
    VAR id age score_sante yhat resid rstud cook leverage;
    FORMAT yhat resid rstud cook leverage 8.4;
RUN;


/* ================================================================== */
/*  10.  ANALYSE DE COVARIANCE (ANCOVA)                                */
/* ================================================================== */

/* ------------------------------------------------------------------ */
/*  10.1  ANCOVA complète                                              */
/* ------------------------------------------------------------------ */

TITLE2 "10.1 — ANCOVA complète — Table ANOVA de type III";
PROC GLM DATA=esps PLOTS=ALL;
    CLASS sexe profession couverture_complementaire
          hospitalisation_12_mois tabagisme activite_physique
          handicap_declare maladies_declarees;
    MODEL score_sante = age revenus_mensuels_euros imc
                        depenses_sante_annuelles_euros
                        nombre_consultations_annuelles
                        nombre_medicaments_reguliers
                        sexe profession couverture_complementaire
                        hospitalisation_12_mois tabagisme
                        activite_physique handicap_declare
                        maladies_declarees / SS3 SOLUTION;
QUIT;

/* ------------------------------------------------------------------ */
/*  10.2  ANCOVA réduite — facteurs significatifs                      */
/* ------------------------------------------------------------------ */

TITLE2 "10.2 — ANCOVA réduite — facteurs significatifs";
PROC GLM DATA=esps PLOTS=ALL;
    CLASS sexe hospitalisation_12_mois activite_physique handicap_declare;
    MODEL score_sante = age
                        nombre_consultations_annuelles
                        nombre_medicaments_reguliers
                        sexe hospitalisation_12_mois
                        activite_physique handicap_declare / SS3 SOLUTION;

    /* LSMEANS — Moyennes marginales estimées (équivalent emmeans) */
    LSMEANS sexe / PDIFF ADJUST=TUKEY CL;
    LSMEANS hospitalisation_12_mois / PDIFF ADJUST=TUKEY CL;
    LSMEANS activite_physique / PDIFF ADJUST=TUKEY CL;
    LSMEANS handicap_declare / PDIFF ADJUST=TUKEY CL;
QUIT;

/* ------------------------------------------------------------------ */
/*  10.3  Test d'interaction Âge × Sexe                                */
/* ------------------------------------------------------------------ */

TITLE2 "10.3 — ANCOVA — Test d'interaction Âge × Sexe";
PROC GLM DATA=esps PLOTS=ALL;
    CLASS sexe;
    MODEL score_sante = age sexe age*sexe / SS3 SOLUTION;
QUIT;

/* Graphique d'interaction */
PROC SGPLOT DATA=esps;
    REG X=age Y=score_sante / GROUP=sexe CLM LINEATTRS=(THICKNESS=2);
    XAXIS LABEL="Âge";
    YAXIS LABEL="Score de santé perçue";
    TITLE3 "Interaction Âge × Sexe sur score_sante";
RUN;


/* ================================================================== */
/*  11.  RÉGRESSION LOGISTIQUE ORDINALE (COTES PROPORTIONNELLES)       */
/* ================================================================== */
/*  etat_sante_percu (5 modalités ordonnées) → PROC LOGISTIC avec      */
/*  LINK=CLOGIT (cumulative logit = proportional odds)                 */
/* ================================================================== */

/* ------------------------------------------------------------------ */
/*  11.1  Modèle ordinal complet                                       */
/* ------------------------------------------------------------------ */

TITLE2 "11.1 — Régression logistique ordinale — Modèle complet";
PROC LOGISTIC DATA=esps PLOTS=(EFFECT ODDSRATIO);
    CLASS sexe (REF="Homme")
          hospitalisation_12_mois (REF="Non")
          tabagisme (REF="Non-fumeur")
          activite_physique (REF="Sédentaire")
          handicap_declare (REF="Non")
          couverture_complementaire (REF="Aucune complémentaire")
          / PARAM=REF;
    MODEL etat_sante_percu (ORDER=INTERNAL DESCENDING) =
          age revenus_mensuels_euros imc
          nombre_consultations_annuelles
          nombre_medicaments_reguliers
          depenses_sante_annuelles_euros
          sexe hospitalisation_12_mois tabagisme
          activite_physique handicap_declare
          couverture_complementaire
          / LINK=CLOGIT RSQUARE LACKFIT;

    /* Test du score pour la proportionnalité des odds               */
    /* (équivalent SAS du test de Brant sous R)                      */
    /* L'option UNEQUALSLOPES fournit le test ligne par ligne.       */
    OUTPUT OUT=pred_ord PREDPROBS=INDIVIDUAL;
QUIT;

/* ------------------------------------------------------------------ */
/*  11.2  Modèle ordinal réduit                                        */
/* ------------------------------------------------------------------ */

TITLE2 "11.2 — Régression logistique ordinale — Modèle réduit";
PROC LOGISTIC DATA=esps PLOTS=(EFFECT ODDSRATIO);
    CLASS sexe (REF="Homme")
          hospitalisation_12_mois (REF="Non")
          activite_physique (REF="Sédentaire")
          handicap_declare (REF="Non")
          / PARAM=REF;
    MODEL etat_sante_percu (ORDER=INTERNAL DESCENDING) =
          age nombre_consultations_annuelles
          nombre_medicaments_reguliers
          sexe hospitalisation_12_mois
          activite_physique handicap_declare
          / LINK=CLOGIT RSQUARE LACKFIT;
QUIT;


/* ================================================================== */
/*  12.  RÉGRESSION LOGISTIQUE BINAIRE                                 */
/* ================================================================== */
/*  Variable réponse : sante_mauvaise (0/1)                            */
/*  0 = Bonne santé (Assez bon + Bon + Très bon)                       */
/*  1 = Mauvaise santé (Mauvais + Très mauvais)                        */
/* ================================================================== */

/* ------------------------------------------------------------------ */
/*  12.1  Modèle binaire complet                                       */
/* ------------------------------------------------------------------ */

TITLE2 "12.1 — Régression logistique binaire — Modèle complet";
PROC LOGISTIC DATA=esps PLOTS=(ROC EFFECT ODDSRATIO INFLUENCE);
    CLASS sexe (REF="Homme")
          hospitalisation_12_mois (REF="Non")
          tabagisme (REF="Non-fumeur")
          activite_physique (REF="Sédentaire")
          handicap_declare (REF="Non")
          / PARAM=REF;
    MODEL sante_mauvaise (EVENT="1") =
          age revenus_mensuels_euros imc
          nombre_consultations_annuelles
          nombre_medicaments_reguliers
          sexe hospitalisation_12_mois tabagisme
          activite_physique handicap_declare
          / RSQUARE LACKFIT CTABLE PPROB=0.5
            OUTROC=roc_data;

    /* Odds Ratios avec IC 95% */
    ODDSRATIO age;
    ODDSRATIO nombre_consultations_annuelles;
    ODDSRATIO nombre_medicaments_reguliers;

    OUTPUT OUT=pred_bin PREDPROBS=INDIVIDUAL PREDICTED=pred_prob;
QUIT;

/* ------------------------------------------------------------------ */
/*  12.2  Sélection Stepwise sur le modèle binaire                     */
/* ------------------------------------------------------------------ */

TITLE2 "12.2 — Régression logistique binaire — Sélection Stepwise";
PROC LOGISTIC DATA=esps;
    CLASS sexe (REF="Homme")
          hospitalisation_12_mois (REF="Non")
          tabagisme (REF="Non-fumeur")
          activite_physique (REF="Sédentaire")
          handicap_declare (REF="Non")
          / PARAM=REF;
    MODEL sante_mauvaise (EVENT="1") =
          age revenus_mensuels_euros imc
          nombre_consultations_annuelles
          nombre_medicaments_reguliers
          sexe hospitalisation_12_mois tabagisme
          activite_physique handicap_declare
          / SELECTION=STEPWISE SLE=0.05 SLS=0.05 RSQUARE LACKFIT;
QUIT;

/* ------------------------------------------------------------------ */
/*  12.3  Courbe ROC et AUC                                            */
/* ------------------------------------------------------------------ */

TITLE2 "12.3 — Courbe ROC";
PROC SGPLOT DATA=roc_data;
    SERIES X=_1MSPEC_ Y=_SENSIT_ / LINEATTRS=(COLOR=steelblue THICKNESS=2);
    LINEPARM X=0 Y=0 SLOPE=1 / LINEATTRS=(PATTERN=DASH COLOR=gray);
    XAXIS LABEL="1 - Spécificité" VALUES=(0 TO 1 BY 0.1);
    YAXIS LABEL="Sensibilité" VALUES=(0 TO 1 BY 0.1);
    TITLE3 "Courbe ROC — Régression logistique binaire";
RUN;

/* ------------------------------------------------------------------ */
/*  12.4  Matrice de confusion                                         */
/* ------------------------------------------------------------------ */

TITLE2 "12.4 — Matrice de confusion (seuil = 0.5)";
DATA pred_class;
    SET pred_bin;
    IF pred_prob >= 0.5 THEN predit = 1;
    ELSE predit = 0;
RUN;

PROC FREQ DATA=pred_class;
    TABLES sante_mauvaise * predit / NOCOL NOROW NOPERCENT;
    TITLE3 "Matrice de confusion";
RUN;

/* Métriques de classification */
PROC FREQ DATA=pred_class;
    TABLES sante_mauvaise * predit / SENSPEC;
RUN;

/* ------------------------------------------------------------------ */
/*  12.5  Pseudo-R² (McFadden, Cox & Snell, Nagelkerke)                */
/*        → Fournis automatiquement par PROC LOGISTIC (option RSQUARE) */
/* ------------------------------------------------------------------ */

/* Les pseudo-R² sont déjà dans la sortie de PROC LOGISTIC (12.1).    */
/* SAS produit automatiquement :                                       */
/*   - Max-rescaled R-Square (= Nagelkerke)                            */
/*   - R-Square (= Cox & Snell)                                        */
/* Le McFadden R² peut être calculé manuellement si nécessaire.        */

/* ------------------------------------------------------------------ */
/*  12.6  Test de Hosmer-Lemeshow                                      */
/*        → Fourni par l'option LACKFIT de PROC LOGISTIC (12.1)        */
/* ------------------------------------------------------------------ */

/* Le test de Hosmer-Lemeshow est produit par LACKFIT dans la section  */
/* 12.1. Il est automatiquement inclus dans la sortie.                 */


/* ================================================================== */
/*  13.  NETTOYAGE ET FIN                                              */
/* ================================================================== */

TITLE;
TITLE2;
TITLE3;
ODS GRAPHICS OFF;

/* ================================================================== */
/*  FIN DU PROGRAMME                                                   */
/*  Ce fichier .sas reproduit l'intégralité des analyses réalisées     */
/*  sous R dans le fichier rapport.Rmd.                                */
/* ================================================================== */
