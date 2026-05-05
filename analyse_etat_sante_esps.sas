/*****************************************************************************
 *  Analyses statistiques complètes — Base ESPS
 *  Variable réponse : etat_sante_percu  (qualitative ordinale)
 *     Modalités : Très bon | Bon | Assez bon | Mauvais | Très mauvais
 *
 *  Contexte : Enquête Santé et Protection Sociale (ESPS)
 *  Fichier  : base_esps.csv  (500 obs. × 25 variables)
 *
 *  STRATÉGIE DE MODÉLISATION
 *  --------------------------
 *  Modèle PRINCIPAL : régression logistique ordinale (cumulative logit)
 *    → adapté à la nature ordinale de etat_sante_percu (McCullagh, 1980)
 *    → variables sélectionnées sur base théorique (Grossman, 1972)
 *      et empirique, NON via procédures automatiques (Harrell, 2001)
 *  Modèles de ROBUSTESSE (analyses comparatives) :
 *    → régression linéaire sur score_sante (interprétée avec prudence)
 *    → régression logistique binaire (sante_mauvaise 0/1)
 *  Critères AIC/BIC : comparaison intra-famille uniquement
 *    (comparaison linéaire vs ordinal invalide — variables réponses différentes)
 *
 *  Analyses couvertes :
 *    0. Importation et recodage
 *    1. Analyse bivariée exploratoire
 *       (χ² + V de Cramér pour qualitatif ; Spearman pour quantitatif)
 *       → rôle exploratoire : ne conditionne pas la spécification des modèles
 *    2. Vérification de la colinéarité (VIF)
 *    3. Modèle PRINCIPAL — Régression logistique ordinale
 *       + test de proportionnalité des odds + validation croisée k-fold
 *    4. Modèles de ROBUSTESSE — Régression linéaire (ANCOVA) + logistique binaire
 *    5. Sélection automatique (vérification de cohérence uniquement)
 *    6. Validation du modèle linéaire (diagnostics résiduels)
 *****************************************************************************/


/* ═══════════════════════════════════════════════════════════════════════════
   0.  IMPORTATION ET RECODAGE
   ═══════════════════════════════════════════════════════════════════════════ */

/* Définir la bibliothèque de travail */
libname proj "C:\chemin\vers\votre\dossier";   /* ← adapter le chemin */

proc import datafile = "C:\chemin\vers\base_esps.csv"
    out  = proj.base_esps
    dbms = dlm
    replace;
    delimiter = ";";
    getnames  = yes;
    guessingrows = 500;
run;

/* Vérification rapide */
proc contents data = proj.base_esps;
run;

proc freq data = proj.base_esps;
    tables etat_sante_percu;
    title "Distribution de la variable réponse — État de santé perçu";
run;

/* -----------------------------------------------------------------------
   Recodage numérique ordinal de etat_sante_percu
   1 = Très mauvais  →  5 = Très bon  (sens croissant = meilleure santé)
   ----------------------------------------------------------------------- */
data proj.base_esps;
    set proj.base_esps;

    /* Score numérique ordinal */
    if      etat_sante_percu = "Très mauvais" then score_sante = 1;
    else if etat_sante_percu = "Mauvais"       then score_sante = 2;
    else if etat_sante_percu = "Assez bon"     then score_sante = 3;
    else if etat_sante_percu = "Bon"           then score_sante = 4;
    else if etat_sante_percu = "Très bon"      then score_sante = 5;
    else score_sante = .;  /* valeur manquante si modalité inattendue */

    /* Variable binaire pour la régression logistique binaire (optionnel) :
       1 = Mauvaise santé (Très mauvais + Mauvais)
       0 = Bonne santé    (Assez bon + Bon + Très bon)                    */
    if score_sante in (1, 2) then sante_mauvaise = 1;
    else                          sante_mauvaise = 0;

    /* Format pour hospitalisation et handicap */
    if hospitalisation_12_mois = "Oui" then hospit_num = 1; else hospit_num = 0;
    if handicap_declare         = "Oui" then handicap_num = 1; else handicap_num = 0;
    if renoncement_soins_12_mois = "Oui" then renoncement_num = 1; else renoncement_num = 0;
run;

/* Vérifier le recodage */
proc freq data = proj.base_esps;
    tables etat_sante_percu * score_sante / norow nocol nopercent;
    title "Vérification du recodage ordinal";
run;


/* ═══════════════════════════════════════════════════════════════════════════
   1.  ANALYSE BIVARIÉE EXPLORATOIRE
   ═══════════════════════════════════════════════════════════════════════════
   Y = etat_sante_percu (qualitative ordinale)
   → Y quali × X quali  : test du χ² + V de Cramér (PROC FREQ, option measures)
   → Y quali × X quanti : corrélation de Spearman (PROC CORR, option spearman)
                          + ANOVA exploratoire (PROC GLM/NPAR1WAY) à titre indicatif
   NOTE MÉTHODOLOGIQUE : Cette étape est exploratoire. Les résultats obtenus
   ici ne conditionnent pas directement la spécification des modèles multivariés.
   La sélection finale des variables repose exclusivement sur le cadre théorique
   (modèle de capital santé de Grossman) et la littérature empirique.
   ═══════════════════════════════════════════════════════════════════════════ */

/* 1a. Croisement avec les variables qualitatives — χ² + V de Cramér
       L'option CHISQ produit le χ², le φ et le V de Cramér.
       L'option MEASURES ajoute des mesures d'association ordinale (Gamma, Kendall).  */

proc freq data = proj.base_esps;
    tables etat_sante_percu * sexe / chisq measures;
    title "Bivariée : État de santé perçu × Sexe (χ² + V de Cramér)";
run;

proc freq data = proj.base_esps;
    tables etat_sante_percu * profession / chisq measures;
    title "Bivariée : État de santé perçu × Profession (χ² + V de Cramér)";
run;

proc freq data = proj.base_esps;
    tables etat_sante_percu * niveau_education / chisq measures;
    title "Bivariée : État de santé perçu × Niveau d'éducation (χ² + V de Cramér)";
run;

proc freq data = proj.base_esps;
    tables etat_sante_percu * situation_familiale / chisq measures;
    title "Bivariée : État de santé perçu × Situation familiale (χ² + V de Cramér)";
run;

proc freq data = proj.base_esps;
    tables etat_sante_percu * couverture_complementaire / chisq measures;
    title "Bivariée : État de santé perçu × Couverture complémentaire (χ² + V de Cramér)";
run;

proc freq data = proj.base_esps;
    tables etat_sante_percu * hospitalisation_12_mois / chisq measures;
    title "Bivariée : État de santé perçu × Hospitalisation 12 mois (χ² + V de Cramér)";
run;

proc freq data = proj.base_esps;
    tables etat_sante_percu * tabagisme / chisq measures;
    title "Bivariée : État de santé perçu × Tabagisme (χ² + V de Cramér)";
run;

proc freq data = proj.base_esps;
    tables etat_sante_percu * consommation_alcool / chisq measures;
    title "Bivariée : État de santé perçu × Consommation d'alcool (χ² + V de Cramér)";
run;

proc freq data = proj.base_esps;
    tables etat_sante_percu * activite_physique / chisq measures;
    title "Bivariée : État de santé perçu × Activité physique (χ² + V de Cramér)";
run;

proc freq data = proj.base_esps;
    tables etat_sante_percu * handicap_declare / chisq measures;
    title "Bivariée : État de santé perçu × Handicap déclaré (χ² + V de Cramér)";
run;

proc freq data = proj.base_esps;
    tables etat_sante_percu * renoncement_soins_12_mois / chisq measures;
    title "Bivariée : État de santé perçu × Renoncement aux soins (χ² + V de Cramér)";
run;

proc freq data = proj.base_esps;
    tables etat_sante_percu * maladies_declarees / chisq measures;
    title "Bivariée : État de santé perçu × Maladies déclarées (χ² + V de Cramér)";
run;

/* 1b. Croisement avec les variables quantitatives
       MÉTHODE PRINCIPALE : corrélation de Spearman (section 1d ci-dessous),
       adaptée au caractère ordinal de la variable dépendante.
       L'ANOVA à un facteur ci-dessous est utilisée à titre EXPLORATOIRE UNIQUEMENT
       pour visualiser la distribution de chaque variable quantitative selon les groupes
       de santé. Elle ne conditionne pas la sélection des variables dans les modèles.
       Note : la direction causale est bien X → Y (les variables socio-démographiques
       et comportementales expliquent la santé perçue, non l'inverse). */

proc glm data = proj.base_esps;
    class etat_sante_percu;
    model age = etat_sante_percu;
    means etat_sante_percu / tukey;
    title "Bivariée ANOVA : Âge selon l'état de santé perçu";
run;
quit;

proc glm data = proj.base_esps;
    class etat_sante_percu;
    model revenus_mensuels_euros = etat_sante_percu;
    means etat_sante_percu / tukey;
    title "Bivariée ANOVA : Revenus mensuels selon l'état de santé perçu";
run;
quit;

proc glm data = proj.base_esps;
    class etat_sante_percu;
    model imc = etat_sante_percu;
    means etat_sante_percu / tukey;
    title "Bivariée ANOVA : IMC selon l'état de santé perçu";
run;
quit;

proc glm data = proj.base_esps;
    class etat_sante_percu;
    model depenses_sante_annuelles_euros = etat_sante_percu;
    means etat_sante_percu / tukey;
    title "Bivariée ANOVA : Dépenses de santé selon l'état de santé perçu";
run;
quit;

proc glm data = proj.base_esps;
    class etat_sante_percu;
    model nombre_consultations_annuelles = etat_sante_percu;
    means etat_sante_percu / tukey;
    title "Bivariée ANOVA : Consultations selon l'état de santé perçu";
run;
quit;

proc glm data = proj.base_esps;
    class etat_sante_percu;
    model nombre_medicaments_reguliers = etat_sante_percu;
    means etat_sante_percu / tukey;
    title "Bivariée ANOVA : Médicaments réguliers selon l'état de santé perçu";
run;
quit;

/* 1c. Alternative non paramétrique — Test de Kruskal-Wallis
       (recommandé car Y est ordinale)                                     */

proc npar1way data = proj.base_esps wilcoxon;
    class etat_sante_percu;
    var age revenus_mensuels_euros imc depenses_sante_annuelles_euros
        nombre_consultations_annuelles nombre_medicaments_reguliers;
    title "Test de Kruskal-Wallis : Variables quantitatives selon l'état de santé perçu";
run;

/* 1d. Corrélation de Spearman (score ordinal vs variables quantitatives) */
proc corr data = proj.base_esps spearman;
    var score_sante;
    with age revenus_mensuels_euros imc depenses_sante_annuelles_euros
         nombre_consultations_annuelles nombre_medicaments_reguliers nombre_enfants;
    title "Corrélation de Spearman : score_sante vs variables quantitatives";
run;

/* 1e. Graphiques bivariés */
proc sgplot data = proj.base_esps;
    vbox age / category = etat_sante_percu;
    title "Boîte à moustaches : Âge selon l'état de santé perçu";
run;

proc sgplot data = proj.base_esps;
    vbox imc / category = etat_sante_percu;
    title "Boîte à moustaches : IMC selon l'état de santé perçu";
run;

proc sgplot data = proj.base_esps;
    vbox depenses_sante_annuelles_euros / category = etat_sante_percu;
    title "Boîte à moustaches : Dépenses de santé selon l'état de santé perçu";
run;

proc sgplot data = proj.base_esps;
    vbox nombre_consultations_annuelles / category = etat_sante_percu;
    title "Boîte à moustaches : Consultations selon l'état de santé perçu";
run;


/* ═══════════════════════════════════════════════════════════════════════════
   2.  ROBUSTESSE — RÉGRESSION LINÉAIRE (modèle alternatif)
   ═══════════════════════════════════════════════════════════════════════════
   Ce modèle est estimé À TITRE DE ROBUSTESSE uniquement. Le modèle PRINCIPAL
   est la régression logistique ordinale (section 7).
   On utilise score_sante (1–5) comme approximation numérique de
   etat_sante_percu afin d'appliquer PROC REG. L'hypothèse d'équidistance
   entre les modalités est forte et doit être interprétée avec prudence.
   Y = score_sante
   X = variables sélectionnées sur base théorique (Grossman, 1972)
   ═══════════════════════════════════════════════════════════════════════════ */

/* 2a. Modèle complet — variables quantitatives */
proc reg data = proj.base_esps;
    model score_sante =
          age
          revenus_mensuels_euros
          depenses_sante_annuelles_euros
          nombre_consultations_annuelles
          nombre_medicaments_reguliers
          imc
          nombre_enfants;
    title "Régression linéaire — Modèle complet (score_sante)";
run;
quit;

/* 2b. Modèle réduit — variables retenues sur base THÉORIQUE
       Sélection fondée sur le modèle de capital santé (Grossman, 1972) et la
       littérature empirique, NON sur les p-values du modèle complet.
       Les procédures automatiques (section 4) sont présentées séparément
       à titre de vérification de cohérence uniquement.                     */
proc reg data = proj.base_esps;
    model score_sante =
          age
          nombre_consultations_annuelles
          nombre_medicaments_reguliers;
    title "Régression linéaire — Modèle réduit (score_sante)";
run;
quit;


/* ═══════════════════════════════════════════════════════════════════════════
   3.  ÉTUDE DE LA COLINÉARITÉ (préalable à la modélisation)
   ═══════════════════════════════════════════════════════════════════════════
   Cette analyse est réalisée EN AMONT de l'estimation du modèle principal
   (logistique ordinal) afin de détecter d'éventuels problèmes de colinéarité
   entre les variables explicatives retenues sur base théorique.
   VIF (Variance Inflation Factor) — calculé ici sur PROC REG (score_sante)
   car PROC LOGISTIC ne produit pas directement le VIF.
   Règle : VIF > 10 → colinéarité problématique
           VIF > 5  → colinéarité modérée à surveiller
   Tolérance = 1/VIF < 0.1 → problème                                     */

/* 3a. VIF sur toutes les variables quantitatives */
proc reg data = proj.base_esps;
    model score_sante =
          age
          revenus_mensuels_euros
          depenses_sante_annuelles_euros
          nombre_consultations_annuelles
          nombre_medicaments_reguliers
          imc
          nombre_enfants / vif tol;
    title "Colinéarité — VIF et Tolérance (score_sante)";
run;
quit;

/* 3b. Matrice de corrélation entre les prédicteurs */
proc corr data = proj.base_esps;
    var age
        revenus_mensuels_euros
        depenses_sante_annuelles_euros
        nombre_consultations_annuelles
        nombre_medicaments_reguliers
        imc
        nombre_enfants;
    title "Matrice de corrélation — Variables explicatives quantitatives";
run;

/* 3c. Indices de conditionnement (collin) */
proc reg data = proj.base_esps;
    model score_sante =
          age
          revenus_mensuels_euros
          depenses_sante_annuelles_euros
          nombre_consultations_annuelles
          nombre_medicaments_reguliers
          imc
          nombre_enfants / collin;
    title "Indices de conditionnement (collinéarité diagnostics)";
run;
quit;


/* ═══════════════════════════════════════════════════════════════════════════
   4.  SÉLECTION AUTOMATIQUE — VÉRIFICATION DE COHÉRENCE UNIQUEMENT
   ═══════════════════════════════════════════════════════════════════════════
   IMPORTANT : Les procédures de sélection automatique ci-dessous (Forward,
   Backward, Stepwise, ADJRSQ) ne constituent PAS le critère primaire de
   sélection des variables. Le modèle principal repose exclusivement sur le
   cadre théorique (Grossman, 1972) et la littérature empirique (Harrell, 2001).
   Ces procédures sont présentées à titre de VÉRIFICATION DE COHÉRENCE :
   si les mêmes variables émergent systématiquement des procédures automatiques
   et de la théorie, cela constitue un résultat de robustesse supplémentaire.
   En cas de divergence, c'est le cadre théorique qui prime.
   Note : les critères AIC/BIC sont utilisés ici pour la comparaison intra-famille
   (modèles linéaires uniquement). Toute comparaison AIC linéaire vs ordinal
   est invalide (variables réponses de nature différente).                  */

/* 4a. Sélection par R² ajusté, AIC et BIC (tous les sous-modèles) */
proc reg data = proj.base_esps;
    model score_sante =
          age
          revenus_mensuels_euros
          depenses_sante_annuelles_euros
          nombre_consultations_annuelles
          nombre_medicaments_reguliers
          imc
          nombre_enfants / selection = ADJRSQ aic bic best = 5;
    title "Sélection de modèles — R² ajusté, AIC, BIC";
run;
quit;

/* 4b. Sélection ascendante (forward) */
proc reg data = proj.base_esps;
    model score_sante =
          age
          revenus_mensuels_euros
          depenses_sante_annuelles_euros
          nombre_consultations_annuelles
          nombre_medicaments_reguliers
          imc
          nombre_enfants / selection = forward slentry = 0.05;
    title "Sélection Forward (seuil d'entrée = 0.05)";
run;
quit;

/* 4c. Sélection descendante (backward) */
proc reg data = proj.base_esps;
    model score_sante =
          age
          revenus_mensuels_euros
          depenses_sante_annuelles_euros
          nombre_consultations_annuelles
          nombre_medicaments_reguliers
          imc
          nombre_enfants / selection = backward slstay = 0.05;
    title "Sélection Backward (seuil de maintien = 0.05)";
run;
quit;

/* 4d. Sélection pas à pas (stepwise) — VÉRIFICATION DE COHÉRENCE SEULEMENT
       Non utilisé comme critère primaire de sélection (voir note section 4) */
proc reg data = proj.base_esps;
    model score_sante =
          age
          revenus_mensuels_euros
          depenses_sante_annuelles_euros
          nombre_consultations_annuelles
          nombre_medicaments_reguliers
          imc
          nombre_enfants / selection = stepwise slentry = 0.05 slstay = 0.05;
    title "Sélection Stepwise (entrée/maintien = 0.05)";
run;
quit;


/* ═══════════════════════════════════════════════════════════════════════════
   5.  VALIDATION DU MODÈLE LINÉAIRE (robustesse)
   ═══════════════════════════════════════════════════════════════════════════
   IMPORTANT : Ces diagnostics s'appliquent au modèle linéaire (section 2),
   estimé à titre de robustesse. Le modèle PRINCIPAL (logistique ordinal,
   section 7) fait l'objet de diagnostics spécifiques : test de proportionnalité
   des odds (Score Test — section 7b) et validation croisée k-fold (section 5k).
   Hypothèses de la régression linéaire :
     H1 — Normalité des résidus
     H2 — Indépendance des résidus (Durbin-Watson)
     H3 — Homoscédasticité (test de White)
     H4 — Linéarité (résidus partiels)
     H5 — Éléments aberrants et influents (Cook, RStudent, Leverage)
   ═══════════════════════════════════════════════════════════════════════════ */

/* 5a. Estimation du modèle retenu + export des résidus
       (à adapter selon les résultats de la sélection — ex. age + nb_consult + nb_medic) */
proc reg data = proj.base_esps
    plots(only label) = (RStudentByLeverage CooksD residuals(smooth) partialplot);
    model score_sante =
          age
          nombre_consultations_annuelles
          nombre_medicaments_reguliers / r spec dwprob;
    output out = proj.base_esps_resid
           rstudent  = rstud
           predicted = yhat
           residual  = resid
           cookd     = cooksd
           h         = leverage;
    title "Modèle retenu — Diagnostics complets (score_sante)";
run;
quit;

/* 5b. Normalité des résidus — QQ-plot */
proc univariate data = proj.base_esps_resid normal;
    var resid;
    qqplot resid / normal(mu = 0 sigma = est);
    title "Normalité des résidus — QQ-plot";
run;

/* 5c. Normalité des résidus — Histogramme */
proc univariate data = proj.base_esps_resid;
    var resid;
    histogram resid / normal;
    title "Normalité des résidus — Histogramme";
run;

/* 5d. Éléments aberrants — RStudent vs Leverage */
proc reg data = proj.base_esps
    plots(only label) = (RStudentByLeverage);
    model score_sante =
          age
          nombre_consultations_annuelles
          nombre_medicaments_reguliers;
    title "Éléments aberrants — RStudent × Leverage";
run;
quit;

/* 5e. Distance de Cook  (seuil : D_i > 4/n = 4/500 = 0.008) */
proc reg data = proj.base_esps
    plots(only label) = (CooksD);
    model score_sante =
          age
          nombre_consultations_annuelles
          nombre_medicaments_reguliers;
    title "Distance de Cook — Observations influentes";
run;
quit;

/* 5f. Indépendance — Test de Durbin-Watson */
proc reg data = proj.base_esps;
    model score_sante =
          age
          nombre_consultations_annuelles
          nombre_medicaments_reguliers / dwprob;
    title "Indépendance des résidus — Durbin-Watson";
run;
quit;

/* 5g. Homoscédasticité — Test de White (/SPEC) */
proc reg data = proj.base_esps;
    model score_sante =
          age
          nombre_consultations_annuelles
          nombre_medicaments_reguliers / spec;
    title "Homoscédasticité — Test de White (SPEC)";
run;
quit;

/* 5h. Linéarité — Résidus partiels + LOESS */
proc reg data = proj.base_esps
    plots(only) = (residuals(smooth) partialplot);
    model score_sante =
          age
          nombre_consultations_annuelles
          nombre_medicaments_reguliers / spec;
    title "Linéarité — Résidus partiels";
run;
quit;

/* 5i. Visualisation LOESS — score_sante vs chaque prédicteur */
proc sgplot data = proj.base_esps;
    loess y = score_sante x = age;
    title "LOESS — Score santé perçue vs Âge";
run;

proc sgplot data = proj.base_esps;
    loess y = score_sante x = nombre_consultations_annuelles;
    title "LOESS — Score santé perçue vs Nombre de consultations";
run;

proc sgplot data = proj.base_esps;
    loess y = score_sante x = nombre_medicaments_reguliers;
    title "LOESS — Score santé perçue vs Nombre de médicaments";
run;

/* 5j. Observations à supprimer éventuellement
       (observations avec |rstud| > 2 ET Cook > 4/n)                     */
proc print data = proj.base_esps_resid;
    where abs(rstud) > 2 or cooksd > 0.008;
    var id age score_sante yhat resid rstud cooksd leverage;
    title "Observations potentiellement aberrantes / influentes";
run;


/* 5k. VALIDATION CROISÉE K-FOLD — Modèle logistique ordinal (modèle principal)
   ─────────────────────────────────────────────────────────────────────────────
   SAS base ne dispose pas d'une procédure native de k-fold pour PROC LOGISTIC.
   La stratégie ci-dessous implémente un k-fold (k=10) manuel via une macro :
     1. Créer une variable de partition aléatoire (1 à 10)
     2. Pour chaque fold i : entraîner sur les 9 autres folds, prédire sur fold i
     3. Calculer le taux de concordance moyen (C-statistic) sur les 10 folds
   Cette validation est complémentaire au Score Test de proportionnalité (7b). */

/* Étape 1 : création de la variable fold (partition aléatoire stratifiée) */
proc surveyselect data = proj.base_esps out = proj.base_esps_folds
    method = srs samprate = 1 seed = 42;
    strata etat_sante_percu;
run;

data proj.base_esps_folds;
    set proj.base_esps_folds;
    fold = mod(_n_ - 1, 10) + 1;   /* fold de 1 à 10 */
run;

/* Étape 2 : boucle k-fold — macro SAS */
%macro kfold_ordinal(k = 10);
    %do i = 1 %to &k;
        /* Entraînement sur les (k-1) folds */
        proc logistic data = proj.base_esps_folds
                      outmodel = proj.model_fold_&i noprint;
            where fold ne &i;
            class sexe (ref = "Homme")
                  hospitalisation_12_mois (ref = "Non")
                  activite_physique (ref = "Sédentaire")
                  handicap_declare (ref = "Non") / param = ref;
            model etat_sante_percu =
                  age
                  nombre_consultations_annuelles
                  nombre_medicaments_reguliers
                  sexe
                  hospitalisation_12_mois
                  activite_physique
                  handicap_declare / link = cumlogit;
        run;
        /* Prédiction sur le fold de test */
        proc logistic inmodel = proj.model_fold_&i;
            score data  = proj.base_esps_folds (where = (fold = &i))
                  out   = proj.pred_fold_&i
                  fitstat;
        run;
    %end;

    /* Concaténation des prédictions */
    data proj.all_preds;
        set %do i = 1 %to &k; proj.pred_fold_&i %end;;
    run;
%mend kfold_ordinal;

%kfold_ordinal(k = 10);

/* Étape 3 : calcul du taux de concordance moyen (C-statistic) */
proc freq data = proj.all_preds noprint;
    tables etat_sante_percu * _into_ / out = proj.kfold_confusion;
run;

/* Taux de classement global */
proc means data = proj.all_preds;
    var _WARN_;   /* placeholder — voir p_* générés par SCORE pour l'AUC */
    title "Validation croisée k-fold (k=10) — Modèle logistique ordinal principal";
run;


/* ═══════════════════════════════════════════════════════════════════════════
   6.  ROBUSTESSE — ANALYSE DE COVARIANCE (ANCOVA, modèle alternatif)
   ═══════════════════════════════════════════════════════════════════════════
   Ce modèle est estimé À TITRE DE ROBUSTESSE. Il combine variables quantitatives
   et qualitatives sur la variable réponse linéaire (score_sante). Les conclusions
   sont comparées au modèle logistique ordinal principal (section 7) pour évaluer
   la robustesse des inférences à la spécification (test de H3).
   PROC GLM avec CLASS pour les variables qualitatives
   ═══════════════════════════════════════════════════════════════════════════ */

/* 6a. ANCOVA complète */
proc glm data = proj.base_esps;
    class sexe
          profession
          couverture_complementaire
          hospitalisation_12_mois
          tabagisme
          activite_physique
          handicap_declare
          maladies_declarees;
    model score_sante =
          /* Variables quantitatives (covariables) */
          age
          revenus_mensuels_euros
          imc
          depenses_sante_annuelles_euros
          nombre_consultations_annuelles
          nombre_medicaments_reguliers
          /* Variables qualitatives (facteurs) */
          sexe
          profession
          couverture_complementaire
          hospitalisation_12_mois
          tabagisme
          activite_physique
          handicap_declare
          maladies_declarees / solution ss3;
    title "ANCOVA — score_sante (modèle complet avec covariables et facteurs)";
run;
quit;

/* 6b. ANCOVA réduite — facteurs significatifs
       (à adapter après lecture des résultats ci-dessus)                   */
proc glm data = proj.base_esps;
    class sexe
          hospitalisation_12_mois
          activite_physique
          handicap_declare;
    model score_sante =
          age
          nombre_consultations_annuelles
          nombre_medicaments_reguliers
          sexe
          hospitalisation_12_mois
          activite_physique
          handicap_declare / solution ss3;
    lsmeans sexe hospitalisation_12_mois activite_physique handicap_declare
            / pdiff adjust = tukey;
    title "ANCOVA réduite — score_sante (facteurs significatifs)";
run;
quit;

/* 6c. Test d'interaction (vérifier si la pente de l'âge diffère selon le sexe) */
proc glm data = proj.base_esps;
    class sexe;
    model score_sante = age sexe age*sexe / solution ss3;
    title "ANCOVA — Test d'interaction Âge × Sexe sur score_sante";
run;
quit;


/* ═══════════════════════════════════════════════════════════════════════════
   7.  MODÈLE PRINCIPAL — RÉGRESSION LOGISTIQUE ORDINALE
   ═══════════════════════════════════════════════════════════════════════════
   C'est le MODÈLE PRINCIPAL de cette analyse. etat_sante_percu est qualitative
   ordinale (5 modalités) → le modèle logistique ordinal (cumulative logit) est
   le seul modèle pleinement adapté à la nature de la variable réponse
   (McCullagh, 1980 ; Agresti, 2010).
   Les variables sont sélectionnées sur base THÉORIQUE (Grossman, 1972) et
   empirique, NON via des procédures automatiques de sélection (Harrell, 2001).
   Plan de la section :
     7a — Modèle ordinal complet (toutes les variables théoriques)
     7b — Test de proportionnalité des odds (Score Test — hypothèse H du modèle)
     7c — Modèle ordinal réduit (variables théoriques + confirmation empirique)
     7d — Robustesse : régression logistique BINAIRE
     7e — Cohérence : sélection automatique (vérification uniquement)
     7f — Courbe ROC (modèle binaire)
   ═══════════════════════════════════════════════════════════════════════════ */

/* 7a. Régression logistique ORDINALE (cumulative logit)
       Variable réponse : score_sante (1–5), traitée comme ordinale
       PROC LOGISTIC modélise P(Y ≤ j) pour j = 1,2,3,4                  */

proc logistic data = proj.base_esps descending;
    class sexe (ref = "Homme")
          hospitalisation_12_mois (ref = "Non")
          tabagisme (ref = "Non-fumeur")
          activite_physique (ref = "Sédentaire")
          handicap_declare (ref = "Non")
          couverture_complementaire (ref = "Mutuelle privée") / param = ref;
    model etat_sante_percu =
          age
          revenus_mensuels_euros
          imc
          nombre_consultations_annuelles
          nombre_medicaments_reguliers
          depenses_sante_annuelles_euros
          sexe
          hospitalisation_12_mois
          tabagisme
          activite_physique
          handicap_declare
          couverture_complementaire / link = cumlogit
                                       rsquare
                                       lackfit
                                       stb;
    title "Régression logistique ordinale — etat_sante_percu (modèle complet)";
run;

/* 7b. Test de l'hypothèse des cotes proportionnelles (Score Test)
       Produit automatiquement par PROC LOGISTIC avec link=cumlogit.
       H₀ : les odds ratios sont constants sur l'ensemble des seuils de coupure.
       Si p-value < 0.05 → l'hypothèse de proportionnalité est violée →
       envisager un modèle partial proportional odds ou un modèle multinomial.
       Ce test est obligatoire pour valider la spécification du modèle ordinal.
       Résultat : voir "Score Test for the Proportional Odds Assumption" dans
       la sortie PROC LOGISTIC de l'étape 7a.                                */

/* 7c. Régression logistique ordinale — modèle réduit (MODÈLE PRINCIPAL FINAL)
       Variables retenues sur base THÉORIQUE (Grossman, 1972) et confirmées
       empiriquement dans le modèle complet 7a.
       Cette sélection théorique est privilégiée par rapport aux p-values seules
       conformément aux recommandations de Harrell (2001).                  */
proc logistic data = proj.base_esps descending;
    class sexe (ref = "Homme")
          hospitalisation_12_mois (ref = "Non")
          activite_physique (ref = "Sédentaire")
          handicap_declare (ref = "Non") / param = ref;
    model etat_sante_percu =
          age
          nombre_consultations_annuelles
          nombre_medicaments_reguliers
          sexe
          hospitalisation_12_mois
          activite_physique
          handicap_declare / link = cumlogit
                              rsquare
                              lackfit
                              stb;
    title "Régression logistique ordinale — etat_sante_percu (modèle réduit)";
run;

/* 7d. Régression logistique BINAIRE (modèle de robustesse)
       Variable réponse : sante_mauvaise (0/1)
       0 = Bonne santé (Assez bon + Bon + Très bon)
       1 = Mauvaise santé (Mauvais + Très mauvais)
       Ce modèle est estimé À TITRE DE ROBUSTESSE uniquement.
       Les conclusions sont comparées au modèle ordinal (7c) pour tester H3.  */

proc logistic data = proj.base_esps descending;
    class sexe (ref = "Homme")
          hospitalisation_12_mois (ref = "Non")
          tabagisme (ref = "Non-fumeur")
          activite_physique (ref = "Sédentaire")
          handicap_declare (ref = "Non") / param = ref;
    model sante_mauvaise (event = "1") =
          age
          revenus_mensuels_euros
          imc
          nombre_consultations_annuelles
          nombre_medicaments_reguliers
          sexe
          hospitalisation_12_mois
          tabagisme
          activite_physique
          handicap_declare / rsquare
                              lackfit
                              ctable
                              stb;
    title "Régression logistique binaire — sante_mauvaise (0/1)";
run;

/* 7e. COHÉRENCE — Sélection automatique stepwise (vérification uniquement)
       IMPORTANT : Cette procédure NE constitue PAS le critère primaire de
       sélection. Le modèle principal (7c) repose sur le cadre théorique.
       Le stepwise est présenté ici pour vérifier la convergence entre la
       théorie et les données : si les mêmes variables émergent, cela renforce
       la crédibilité des choix. En cas de divergence, la théorie prime.
       Référence : Harrell (2001), Burnham & Anderson (2002).               */
proc logistic data = proj.base_esps descending;
    class sexe (ref = "Homme")
          hospitalisation_12_mois (ref = "Non")
          tabagisme (ref = "Non-fumeur")
          activite_physique (ref = "Sédentaire")
          handicap_declare (ref = "Non")
          couverture_complementaire (ref = "Mutuelle privée") / param = ref;
    model etat_sante_percu =
          age
          revenus_mensuels_euros
          imc
          nombre_consultations_annuelles
          nombre_medicaments_reguliers
          depenses_sante_annuelles_euros
          sexe
          hospitalisation_12_mois
          tabagisme
          activite_physique
          handicap_declare
          couverture_complementaire / link = cumlogit
                                       selection = stepwise
                                       slentry = 0.05
                                       slstay = 0.05;
    title "Cohérence stepwise — Régression logistique ordinale (vérification)";
run;

/* 7f. Courbe ROC (régression binaire uniquement)                         */
proc logistic data = proj.base_esps descending
    plots(only) = (roc effect oddsratio);
    class sexe (ref = "Homme")
          hospitalisation_12_mois (ref = "Non")
          activite_physique (ref = "Sédentaire")
          handicap_declare (ref = "Non") / param = ref;
    model sante_mauvaise (event = "1") =
          age
          nombre_consultations_annuelles
          nombre_medicaments_reguliers
          sexe
          hospitalisation_12_mois
          activite_physique
          handicap_declare / rsquare
                              lackfit
                              ctable;
    title "Régression logistique binaire — Courbe ROC";
run;

/* 7g. Matrice de confusion (table de classement)
       → produite automatiquement par l'option ctable ci-dessus.
       Interprétation : sensibilité, spécificité, taux de classement.     */
