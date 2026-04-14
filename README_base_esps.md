# Base de données synthétique — Enquête Santé et Protection Sociale (ESPS)

## Référence méthodologique

| Élément              | Détail                                                                 |
|----------------------|------------------------------------------------------------------------|
| **Source**           | IRDES — Enquête Santé et Protection Sociale (ESPS)                     |
| **Méthodologie**     | Enquête en coupe transversale (*cross-sectional survey*)               |
| **Unité statistique**| Individu résidant en France métropolitaine                             |
| **Fichier**          | `base_esps_synthétique.csv`                                            |
| **Encodage**         | UTF-8                                                                  |
| **Séparateur**       | Point-virgule (`;`)                                                    |
| **Observations**     | 500 individus                                                          |
| **Variables**        | 25                                                                     |

> **Note** : les données sont **synthétiques** (générées aléatoirement) et ne
> proviennent pas de l'ESPS réelle. Elles reproduisent fidèlement la
> **structure** et les **distributions plausibles** des variables de l'enquête
> de référence.

---

## Dictionnaire des variables

| #  | Variable                           | Type          | Description                                            | Modalités / Unité                                                                                   |
|----|------------------------------------|---------------|--------------------------------------------------------|------------------------------------------------------------------------------------------------------|
| 1  | `id`                               | Identifiant   | Identifiant unique de l'individu                       | Entier (1 → 500)                                                                                     |
| 2  | `age`                              | Quantitative  | Âge de l'individu                                      | 18 – 95 ans                                                                                          |
| 3  | `sexe`                             | Qualitative   | Sexe                                                   | Homme, Femme                                                                                         |
| 4  | `profession`                       | Qualitative   | Catégorie socioprofessionnelle                         | Agriculteur, Artisan/Commerçant, Cadre supérieur, Profession intermédiaire, Employé, Ouvrier, Retraité, Sans activité professionnelle, Étudiant |
| 5  | `niveau_education`                 | Qualitative   | Niveau de diplôme le plus élevé                        | Sans diplôme, CAP/BEP, Baccalauréat, Bac+2, Bac+3/Licence, Bac+5/Master, Doctorat                  |
| 6  | `situation_familiale`              | Qualitative   | Situation matrimoniale                                 | Célibataire, Marié(e), Pacsé(e), Divorcé(e), Veuf/Veuve                                             |
| 7  | `nombre_enfants`                   | Quantitative  | Nombre d'enfants à charge                              | 0 – 5                                                                                                |
| 8  | `region`                           | Qualitative   | Région de résidence                                    | 13 régions métropolitaines                                                                           |
| 9  | `type_commune`                     | Qualitative   | Taille de la commune de résidence                      | Rurale, Urbaine petite, Urbaine moyenne, Métropole                                                   |
| 10 | `revenus_mensuels_euros`           | Quantitative  | Revenus mensuels nets (€)                              | Distribution gaussienne centrée selon la profession                                                  |
| 11 | `statut_assurance`                 | Qualitative   | Régime d'assurance maladie obligatoire                 | Régime général, MSA, RSI/SSI, Régime spécial, Autre régime                                          |
| 12 | `couverture_complementaire`        | Qualitative   | Type de couverture complémentaire santé                | Mutuelle privée, CSS, Assurance privée, Aucune complémentaire                                       |
| 13 | `depenses_sante_annuelles_euros`   | Quantitative  | Dépenses de santé annuelles (€)                        | Corrélées positivement à l'âge                                                                       |
| 14 | `nombre_consultations_annuelles`   | Quantitative  | Nombre de consultations médicales sur 12 mois          | 0 – 30                                                                                               |
| 15 | `nombre_medicaments_reguliers`     | Quantitative  | Nombre de médicaments pris régulièrement               | Corrélé à l'âge                                                                                      |
| 16 | `hospitalisation_12_mois`          | Qualitative   | Hospitalisation au cours des 12 derniers mois          | Oui, Non                                                                                             |
| 17 | `etat_sante_percu`                 | Qualitative   | Auto-évaluation de l'état de santé                     | Très bon, Bon, Assez bon, Mauvais, Très mauvais                                                     |
| 18 | `maladies_declarees`               | Qualitative   | Maladie chronique principale déclarée                  | Aucune, Diabète, Hypertension, Asthme, Dépression, Lombalgie chronique, Arthrose, Cardiopathie, Cancer (rémission), Maladie respiratoire chronique, Trouble anxieux, Migraine chronique, Obésité morbide |
| 19 | `imc`                              | Quantitative  | Indice de masse corporelle                             | 15.0 – 50.0 (moyenne ≈ 25.5)                                                                        |
| 20 | `tabagisme`                        | Qualitative   | Statut tabagique                                       | Non-fumeur, Ancien fumeur, Fumeur occasionnel, Fumeur quotidien                                     |
| 21 | `consommation_alcool`              | Qualitative   | Fréquence de consommation d'alcool                     | Jamais, Occasionnelle, Régulière, Quotidienne                                                        |
| 22 | `activite_physique`                | Qualitative   | Niveau d'activité physique                             | Sédentaire, Activité légère, Activité modérée, Activité intense                                     |
| 23 | `handicap_declare`                 | Qualitative   | Handicap ou limitation déclaré(e)                      | Oui, Non                                                                                             |
| 24 | `renoncement_soins_12_mois`        | Qualitative   | Renoncement à des soins pour raisons financières       | Oui, Non                                                                                             |
| 25 | `satisfaction_systeme_soins`       | Qualitative   | Satisfaction vis-à-vis du système de soins             | Très satisfait, Satisfait, Peu satisfait, Pas du tout satisfait                                      |

---

## Répartition des types de variables

| Type          | Nombre | Variables                                                                                                              |
|---------------|--------|------------------------------------------------------------------------------------------------------------------------|
| Identifiant   | 1      | `id`                                                                                                                   |
| Quantitatives | 7      | `age`, `nombre_enfants`, `revenus_mensuels_euros`, `depenses_sante_annuelles_euros`, `nombre_consultations_annuelles`, `nombre_medicaments_reguliers`, `imc` |
| Qualitatives  | 17     | `sexe`, `profession`, `niveau_education`, `situation_familiale`, `region`, `type_commune`, `statut_assurance`, `couverture_complementaire`, `hospitalisation_12_mois`, `etat_sante_percu`, `maladies_declarees`, `tabagisme`, `consommation_alcool`, `activite_physique`, `handicap_declare`, `renoncement_soins_12_mois`, `satisfaction_systeme_soins` |

---

## Corrélations intégrées dans la génération

Pour renforcer le réalisme des données, le script de génération (`generate_esps_database.py`) intègre les corrélations suivantes :

- **Profession ↔ Âge** : les retraités sont majoritairement ≥ 65 ans ; les étudiants ≤ 25 ans
- **Revenus ↔ Profession** : les cadres ont des revenus plus élevés que les ouvriers
- **Dépenses de santé ↔ Âge** : les dépenses augmentent avec l'âge
- **Consultations ↔ Âge** : le nombre de consultations croît avec l'âge
- **État de santé perçu ↔ Âge** : dégradation perçue avec l'avancée en âge
- **Handicap ↔ Âge** : probabilité de handicap déclaré croissante avec l'âge
- **Renoncement aux soins ↔ Revenus** : le renoncement est plus fréquent chez les bas revenus

---

## Utilisation

```bash
# Générer (ou régénérer) la base de données
python3 generate_esps_database.py

# Charger dans Python / pandas
import pandas as pd
df = pd.read_csv("base_esps_synthétique.csv", sep=";", encoding="utf-8")
print(df.describe())

# Charger dans R
df <- read.csv2("base_esps_synthétique.csv", fileEncoding = "UTF-8")
summary(df)
```

### Régression linéaire sous SAS

Le fichier **`regression_lineaire_esps.sas`** contient un pipeline complet de
régression linéaire multiple avec `depenses_sante_annuelles_euros` comme
variable réponse. Il couvre les étapes suivantes :

| #  | Étape                                    | Procédure SAS                    |
|----|------------------------------------------|----------------------------------|
| 0  | Importation CSV                          | `PROC IMPORT`                    |
| 1  | Modèle complet (quantitatif)             | `PROC REG`                       |
| 2  | Suppression des variables non sign.      | `PROC REG`                       |
| 3  | Multicolinéarité (VIF)                   | `PROC REG … /VIF`               |
| 4  | Sélection de modèle (R² aj., AIC, BIC)  | `PROC REG … /SELECTION`         |
| 5  | Éléments aberrants (RStudent × Leverage) | `PROC REG plots(…)`             |
| 6  | Résidus studentisés                      | `PROC REG … /R`                 |
| 7  | Distance de Cook                         | `PROC REG plots(CooksD)`        |
| 8  | Normalité (QQ-plot + histogramme)        | `PROC UNIVARIATE`               |
| 9  | Indépendance (Durbin-Watson)             | `PROC REG … /DWPROB`            |
| 10 | Visualisation LOESS                      | `PROC SGPLOT`                    |
| 11 | Homoscédasticité (test de White)         | `PROC REG … /SPEC`              |
| 12 | Linéarité (résidus partiels)             | `PROC REG plots(partialplot)`   |
| 13 | Modèle avec variables qualitatives       | `PROC GLM … CLASS`              |
| 14 | Matrice de corrélation                   | `PROC CORR`                      |

> **Avant exécution** : adaptez le chemin de la bibliothèque `libname proj`
> et le chemin du fichier CSV dans `PROC IMPORT`.

### Analyses complètes — État de santé perçu sous SAS

Le fichier **`analyse_etat_sante_esps.sas`** contient un pipeline complet
avec `etat_sante_percu` (qualitative ordinale, 5 modalités) comme variable
réponse. Il couvre les analyses suivantes :

| #  | Analyse                                  | Procédure(s) SAS                 |
|----|------------------------------------------|----------------------------------|
| 0  | Importation et recodage ordinal (1–5)    | `DATA step`, `PROC IMPORT`      |
| 1  | Analyse bivariée                         | `PROC FREQ (Chi²)`, `PROC GLM (ANOVA)`, `PROC NPAR1WAY (Kruskal-Wallis)`, `PROC CORR (Spearman)`, `PROC SGPLOT` |
| 2  | Régression linéaire et R²                | `PROC REG` (sur `score_sante`)  |
| 3  | Étude de la colinéarité                  | `PROC REG … /VIF TOL COLLIN`, `PROC CORR` |
| 4  | Sélection de variables                   | `PROC REG … /SELECTION` (ADJRSQ, forward, backward, stepwise) |
| 5  | Validation du modèle                     | QQ-plot, histogramme (`PROC UNIVARIATE`), Durbin-Watson, White, Cook, RStudent, LOESS |
| 6  | Analyse de covariance (ANCOVA)           | `PROC GLM … CLASS` (covariables + facteurs, interactions, LSMEANS) |
| 7  | Régression logistique                    | `PROC LOGISTIC` (ordinale `cumlogit` + binaire, stepwise, ROC) |

> **Note** : `etat_sante_percu` étant qualitative ordinale, le script crée
> une variable numérique `score_sante` (1 = Très mauvais → 5 = Très bon)
> pour les analyses nécessitant une variable numérique (régression linéaire,
> ANCOVA). La régression logistique ordinale utilise directement la variable
> caractère d'origine.

### Analyses complètes — État de santé perçu sous R (Rmd)

Le fichier **`analyse_etat_sante_esps.Rmd`** est la transposition complète en
R du script SAS ci-dessus. Il reprend les 7 mêmes analyses avec le YAML
d'un projet de recherche (bookdown / xelatex) :

| #  | Analyse                                  | Packages R principaux              |
|----|------------------------------------------|------------------------------------|
| 0  | Importation et recodage ordinal (1–5)    | base R, `dplyr::case_when`         |
| 1  | Analyse bivariée                         | `chisq.test`, `aov`, `kruskal.test`, `cor.test (Spearman)`, `ggplot2` |
| 2  | Régression linéaire et R²                | `lm`, `summary`                    |
| 3  | Étude de la colinéarité                  | `car::vif`, `corrplot`, `kappa`    |
| 4  | Sélection de variables                   | `leaps::regsubsets`, `step` (AIC, forward, backward, stepwise) |
| 5  | Validation du modèle                     | `shapiro.test`, `lmtest::dwtest`, `lmtest::bptest`, `cooks.distance`, `rstudent`, `ggplot2 (LOESS)` |
| 6  | Analyse de covariance (ANCOVA)           | `lm`, `car::Anova (type III)`, `emmeans` (LSMEANS + Tukey) |
| 7  | Régression logistique                    | `MASS::polr` (ordinale), `glm (binomial)`, `pROC (ROC/AUC)`, `step` |

> **Packages nécessaires** : `tidyverse`, `knitr`, `kableExtra`, `car`,
> `MASS`, `lmtest`, `corrplot`, `broom`, `pROC`, `emmeans`, `leaps`,
> `olsrr`, `patchwork`. Optionnels : `brant`, `ResourceSelection`.

---

## Licence et avertissement

Ces données sont **purement synthétiques** et destinées à des fins **pédagogiques
et méthodologiques**. Elles ne doivent pas être utilisées pour tirer des
conclusions sur la santé de la population française. Pour des analyses réelles,
se référer aux données officielles de l'IRDES :
<https://www.irdes.fr/recherche/enquetes/esps-enquete-sur-la-sante-et-la-protection-sociale/>
