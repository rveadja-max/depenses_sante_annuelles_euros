/*****************************************************************************
 *  Analyses statistiques complètes — Base ESPS synthétique
 *  Variable réponse : etat_sante_percu  (qualitative ordinale)
 *     Modalités : Très bon | Bon | Assez bon | Mauvais | Très mauvais
 *
 *  Contexte : Enquête Santé et Protection Sociale (ESPS)
 *  Fichier  : base_esps_synthétique.csv  (500 obs. × 25 variables)
 *
 *  Analyses couvertes :
 *    0. Importation et recodage
 *    1. Analyse bivariée
 *    2. Régression linéaire et R²
 *    3. Étude de la colinéarité
 *    4. Sélection de variables
 *    5. Validation du modèle
 *    6. Analyse de covariance (ANCOVA)
 *    7. Régression logistique ordinale
 *****************************************************************************/


/* ═══════════════════════════════════════════════════════════════════════════
   0.  IMPORTATION ET RECODAGE
   ═══════════════════════════════════════════════════════════════════════════ */

/* Définir la bibliothèque de travail */
libname proj "C:\chemin\vers\votre\dossier";   /* ← adapter le chemin */

proc import datafile = "C:\chemin\vers\base_esps_synthétique.csv"
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
   1.  ANALYSE BIVARIÉE
   ═══════════════════════════════════════════════════════════════════════════
   Y = etat_sante_percu (qualitative ordinale)
   → Y quali × X quali  : test du Chi-2 (PROC FREQ)
   → Y quali × X quanti : ANOVA ou Kruskal-Wallis (PROC NPAR1WAY)
   ═══════════════════════════════════════════════════════════════════════════ */

/* 1a. Croisement avec les variables qualitatives — Test du Chi-2 */

proc freq data = proj.base_esps;
    tables etat_sante_percu * sexe / chisq expected cellchi2 norow nocol;
    title "Bivariée : État de santé perçu × Sexe";
run;

proc freq data = proj.base_esps;
    tables etat_sante_percu * profession / chisq expected;
    title "Bivariée : État de santé perçu × Profession";
run;

proc freq data = proj.base_esps;
    tables etat_sante_percu * niveau_education / chisq expected;
    title "Bivariée : État de santé perçu × Niveau d'éducation";
run;

proc freq data = proj.base_esps;
    tables etat_sante_percu * situation_familiale / chisq expected;
    title "Bivariée : État de santé perçu × Situation familiale";
run;

proc freq data = proj.base_esps;
    tables etat_sante_percu * couverture_complementaire / chisq expected;
    title "Bivariée : État de santé perçu × Couverture complémentaire";
run;

proc freq data = proj.base_esps;
    tables etat_sante_percu * hospitalisation_12_mois / chisq expected;
    title "Bivariée : État de santé perçu × Hospitalisation 12 mois";
run;

proc freq data = proj.base_esps;
    tables etat_sante_percu * tabagisme / chisq expected;
    title "Bivariée : État de santé perçu × Tabagisme";
run;

proc freq data = proj.base_esps;
    tables etat_sante_percu * consommation_alcool / chisq expected;
    title "Bivariée : État de santé perçu × Consommation d'alcool";
run;

proc freq data = proj.base_esps;
    tables etat_sante_percu * activite_physique / chisq expected;
    title "Bivariée : État de santé perçu × Activité physique";
run;

proc freq data = proj.base_esps;
    tables etat_sante_percu * handicap_declare / chisq expected;
    title "Bivariée : État de santé perçu × Handicap déclaré";
run;

proc freq data = proj.base_esps;
    tables etat_sante_percu * renoncement_soins_12_mois / chisq expected;
    title "Bivariée : État de santé perçu × Renoncement aux soins";
run;

proc freq data = proj.base_esps;
    tables etat_sante_percu * maladies_declarees / chisq expected;
    title "Bivariée : État de santé perçu × Maladies déclarées";
run;

/* 1b. Croisement avec les variables quantitatives
       ANOVA à un facteur : Y = etat_sante_percu (facteur), X = variable quanti
       Ou, de façon équivalente, comparaison de moyennes de X selon les groupes de Y */

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
   2.  RÉGRESSION LINÉAIRE ET R²
   ═══════════════════════════════════════════════════════════════════════════
   On utilise score_sante (1–5) comme approximation numérique de
   etat_sante_percu pour appliquer PROC REG.
   Y = score_sante
   X = variables quantitatives de la base ESPS
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

/* 2b. Modèle réduit — variables significatives uniquement
       (à adapter après lecture des p-values du modèle complet)           */
proc reg data = proj.base_esps;
    model score_sante =
          age
          nombre_consultations_annuelles
          nombre_medicaments_reguliers;
    title "Régression linéaire — Modèle réduit (score_sante)";
run;
quit;


/* ═══════════════════════════════════════════════════════════════════════════
   3.  ÉTUDE DE LA COLINÉARITÉ
   ═══════════════════════════════════════════════════════════════════════════
   VIF (Variance Inflation Factor)
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
   4.  SÉLECTION DE VARIABLES
   ═══════════════════════════════════════════════════════════════════════════ */

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

/* 4d. Sélection pas à pas (stepwise) */
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
   5.  VALIDATION DU MODÈLE
   ═══════════════════════════════════════════════════════════════════════════
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


/* ═══════════════════════════════════════════════════════════════════════════
   6.  ANALYSE DE COVARIANCE  (ANCOVA)
   ═══════════════════════════════════════════════════════════════════════════
   ANCOVA = modèle mixte : variables quantitatives + qualitatives
   Y = score_sante (numérique)
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
   7.  RÉGRESSION LOGISTIQUE
   ═══════════════════════════════════════════════════════════════════════════
   etat_sante_percu est qualitative ordinale (5 modalités) → on utilise
   le modèle logistique ordinal (cumulative logit) via PROC LOGISTIC.
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
       Le test est produit automatiquement par PROC LOGISTIC avec link=cumlogit.
       Si p-value < 0.05 → l'hypothèse de proportionnalité est violée.    */

/* 7c. Régression logistique ordinale — modèle réduit
       (à adapter après lecture des p-values du modèle complet)           */
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

/* 7d. Régression logistique BINAIRE (optionnel)
       Variable réponse : sante_mauvaise (0/1)
       0 = Bonne santé (Assez bon + Bon + Très bon)
       1 = Mauvaise santé (Mauvais + Très mauvais)                        */

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

/* 7e. Sélection de variables en régression logistique (stepwise) */
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
    title "Sélection stepwise — Régression logistique ordinale";
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
