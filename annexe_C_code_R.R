###############################################################################
#  ANNEXE C — Code R complet
#  Reproduction fidèle des analyses du code SAS (analyse_etat_sante_esps.sas)
#
#  Variable réponse : etat_sante_percu (qualitative ordinale, 5 modalités)
#  Base : base_esps.csv (500 obs. × 25 variables, ESPS — IRDES)
#
#  STRATÉGIE DE MODÉLISATION (identique au SAS)
#  ─────────────────────────────────────────────
#  Modèle PRINCIPAL : régression logistique ordinale (cumulative logit)
#    → MASS::polr() ≡ PROC LOGISTIC / link = cumlogit
#  Modèles de ROBUSTESSE :
#    → lm()         ≡ PROC REG     (régression linéaire sur score_sante)
#    → glm(binomial)≡ PROC LOGISTIC (logistique binaire, sante_mauvaise 0/1)
#
#  Correspondances SAS → R section par section :
#    §0 IMPORTATION     : read.csv2()
#    §1 BIVARIÉ         : chisq.test() + vcd::assocstats() + cor.test(Spearman)
#    §2 RÉGR. LINÉAIRE  : lm()
#    §3 COLINÉARITÉ     : car::vif() + corrplot::corrplot()
#    §4 SÉLECTION AUTO  : leaps::regsubsets() + step()
#    §5 VALIDATION      : rstudent(), cooks.distance(), lmtest::dwtest/bptest()
#    §5k K-FOLD         : MASS::polr() en boucle (k = 10)
#    §6 ANCOVA          : lm() + car::Anova(type=III) + emmeans::emmeans()
#    §7 LOGIT ORDINAL   : MASS::polr() + brant::brant() + pROC::roc()
#
#  Packages requis (installer si absent) :
#    install.packages(c("dplyr", "ggplot2", "car", "MASS", "lmtest", "sandwich",
#                       "corrplot", "pROC", "emmeans", "leaps", "vcd", "brant"))
###############################################################################

# ─── Chargement des bibliothèques ────────────────────────────────────────────
library(dplyr)
library(ggplot2)
library(car)
library(MASS)
library(lmtest)
library(sandwich)
library(corrplot)
library(pROC)
library(emmeans)
library(leaps)
library(vcd)      # assocstats() → V de Cramér


# ═══════════════════════════════════════════════════════════════════════════════
# 0.  IMPORTATION ET RECODAGE
# ═══════════════════════════════════════════════════════════════════════════════

# 0a. Importation CSV (séparateur ";" encodage UTF-8)
#     Équivalent SAS : PROC IMPORT dbms = dlm ; delimiter = ";" ;
esps <- read.csv2("data/base_esps.csv",
                  fileEncoding = "UTF-8",
                  stringsAsFactors = TRUE)

# Vérification rapide (équivalent : PROC CONTENTS)
str(esps)
cat("\n--- Distribution de etat_sante_percu ---\n")
print(table(esps$etat_sante_percu))

# ───────────────────────────────────────────────────────────────────────────
#  Recodage numérique ordinal de etat_sante_percu
#  1 = Très mauvais  →  5 = Très bon  (sens croissant = meilleure santé)
#  Équivalent SAS : DATA step  if etat_sante_percu = "Très mauvais" then score_sante = 1; ...
# ───────────────────────────────────────────────────────────────────────────
esps$score_sante <- dplyr::case_when(
  esps$etat_sante_percu == "Très mauvais" ~ 1L,
  esps$etat_sante_percu == "Mauvais"       ~ 2L,
  esps$etat_sante_percu == "Assez bon"     ~ 3L,
  esps$etat_sante_percu == "Bon"           ~ 4L,
  esps$etat_sante_percu == "Très bon"      ~ 5L,
  TRUE ~ NA_integer_
)

# Mettre etat_sante_percu en facteur ordonné (nécessaire pour MASS::polr)
esps$etat_sante_percu <- factor(
  esps$etat_sante_percu,
  levels  = c("Très mauvais", "Mauvais", "Assez bon", "Bon", "Très bon"),
  ordered = TRUE
)

# Variable binaire : 1 = Mauvaise santé (score ≤ 2), 0 = Bonne santé
#   Équivalent SAS : if score_sante in (1, 2) then sante_mauvaise = 1;
esps$sante_mauvaise <- ifelse(esps$score_sante <= 2, 1L, 0L)

# Variables auxiliaires numériques (équivalent DATA step)
esps$hospit_num      <- ifelse(esps$hospitalisation_12_mois   == "Oui", 1, 0)
esps$handicap_num    <- ifelse(esps$handicap_declare          == "Oui", 1, 0)
esps$renoncement_num <- ifelse(esps$renoncement_soins_12_mois == "Oui", 1, 0)

# Vérifier le recodage (équivalent : PROC FREQ / tables etat_sante_percu * score_sante)
cat("\n--- Vérification du recodage ordinal ---\n")
print(table(as.character(esps$etat_sante_percu), esps$score_sante))


# ═══════════════════════════════════════════════════════════════════════════════
# 1.  ANALYSE BIVARIÉE EXPLORATOIRE
# ═══════════════════════════════════════════════════════════════════════════════
# NOTE MÉTHODOLOGIQUE : étape exploratoire uniquement.
# La sélection des variables repose sur le cadre théorique (Grossman, 1972),
# NON sur les résultats de cette analyse bivariée.

# ─────────────────────────────────────────────────────────────────────────────
# 1a. Variables qualitatives — χ² + V de Cramér
#     Équivalent SAS : PROC FREQ / chisq measures ;
# ─────────────────────────────────────────────────────────────────────────────
vars_quali <- c("sexe", "profession", "niveau_education", "situation_familiale",
                "couverture_complementaire", "hospitalisation_12_mois",
                "tabagisme", "consommation_alcool", "activite_physique",
                "handicap_declare", "renoncement_soins_12_mois", "maladies_declarees")

cat("\n", strrep("═", 70), "\n")
cat("1a. χ² + V de Cramér — Variables qualitatives\n")
cat(strrep("═", 70), "\n")

for (v in vars_quali) {
  cat("\n--- État de santé perçu ×", v, "---\n")
  tbl <- table(esps$etat_sante_percu, esps[[v]])
  # Test du chi-2
  print(chisq.test(tbl))
  # V de Cramér + Gamma + tau-b de Kendall (vcd::assocstats)
  ass <- vcd::assocstats(tbl)
  cat(sprintf("  V de Cramér : %.4f\n", ass$cramer))
  cat(sprintf("  Phi         : %.4f\n", ass$phi))
}

# ─────────────────────────────────────────────────────────────────────────────
# 1b. Variables quantitatives — ANOVA exploratoire (Tukey)
#     Équivalent SAS : PROC GLM class etat_sante_percu; model X = etat_sante_percu; means / tukey;
#     NOTE : rôle EXPLORATOIRE uniquement — Spearman (1d) = test principal
# ─────────────────────────────────────────────────────────────────────────────
vars_quant <- c("age", "revenus_mensuels_euros", "imc",
                "depenses_sante_annuelles_euros",
                "nombre_consultations_annuelles", "nombre_medicaments_reguliers")

cat("\n", strrep("═", 70), "\n")
cat("1b. ANOVA exploratoire — Variables quantitatives (rôle indicatif)\n")
cat(strrep("═", 70), "\n")

for (v in vars_quant) {
  cat("\n--- ANOVA :", v, "selon etat_sante_percu ---\n")
  fit_av <- aov(as.formula(paste(v, "~ etat_sante_percu")), data = esps)
  print(summary(fit_av))
  cat("  Comparaisons multiples de Tukey :\n")
  print(TukeyHSD(fit_av))
}

# ─────────────────────────────────────────────────────────────────────────────
# 1c. Alternative non paramétrique — Kruskal-Wallis
#     Équivalent SAS : PROC NPAR1WAY wilcoxon ;
# ─────────────────────────────────────────────────────────────────────────────
cat("\n", strrep("═", 70), "\n")
cat("1c. Test de Kruskal-Wallis\n")
cat(strrep("═", 70), "\n")

for (v in vars_quant) {
  kt <- kruskal.test(as.formula(paste(v, "~ etat_sante_percu")), data = esps)
  cat(sprintf("%-40s : H = %7.3f   df = %d   p = %.4f\n",
              v, kt$statistic, kt$parameter, kt$p.value))
}

# ─────────────────────────────────────────────────────────────────────────────
# 1d. Corrélation de Spearman — TEST PRINCIPAL pour les variables quantitatives
#     Équivalent SAS : PROC CORR spearman ; var score_sante ; with age ... ;
# ─────────────────────────────────────────────────────────────────────────────
cat("\n", strrep("═", 70), "\n")
cat("1d. Corrélation de Spearman — score_sante vs variables quantitatives\n")
cat(strrep("═", 70), "\n")

vars_with <- c("age", "revenus_mensuels_euros", "imc",
               "depenses_sante_annuelles_euros",
               "nombre_consultations_annuelles",
               "nombre_medicaments_reguliers", "nombre_enfants")

for (v in vars_with) {
  r <- cor.test(esps$score_sante, esps[[v]], method = "spearman")
  cat(sprintf("%-40s : rho = %7.4f   p = %.4f\n", v, r$estimate, r$p.value))
}

# ─────────────────────────────────────────────────────────────────────────────
# 1e. Graphiques bivariés — boîtes à moustaches
#     Équivalent SAS : PROC SGPLOT ; vbox X / category = etat_sante_percu ;
# ─────────────────────────────────────────────────────────────────────────────
for (v in c("age", "imc",
            "depenses_sante_annuelles_euros",
            "nombre_consultations_annuelles")) {
  p <- ggplot(esps, aes(x = etat_sante_percu, y = .data[[v]],
                        fill = etat_sante_percu)) +
    geom_boxplot(outlier.size = 0.8, alpha = 0.7) +
    scale_fill_brewer(palette = "RdYlGn") +
    labs(x = "État de santé perçu", y = v,
         title = paste("Distribution de", v, "selon l'état de santé perçu")) +
    theme_minimal(base_size = 10) +
    theme(legend.position = "none",
          plot.title = element_text(face = "bold", hjust = 0.5))
  print(p)
}


# ═══════════════════════════════════════════════════════════════════════════════
# 2.  ROBUSTESSE — RÉGRESSION LINÉAIRE (modèle alternatif)
# ═══════════════════════════════════════════════════════════════════════════════
# Modèle estimé À TITRE DE ROBUSTESSE uniquement.
# Modèle PRINCIPAL = logistique ordinal (§7).
# Équivalent SAS : PROC REG ; model score_sante = ... ;

# 2a. Modèle complet — variables quantitatives
lm_complet <- lm(score_sante ~ age + revenus_mensuels_euros +
                   depenses_sante_annuelles_euros +
                   nombre_consultations_annuelles +
                   nombre_medicaments_reguliers + imc + nombre_enfants,
                 data = esps)

cat("\n", strrep("═", 70), "\n")
cat("2a. Régression linéaire — Modèle complet (score_sante)\n")
cat(strrep("═", 70), "\n")
print(summary(lm_complet))

# 2b. Modèle réduit — variables retenues sur base THÉORIQUE (Grossman, 1972)
#     Sélection théorique, NON basée sur les p-values du modèle complet.
lm_reduit <- lm(score_sante ~ age + nombre_consultations_annuelles +
                  nombre_medicaments_reguliers,
                data = esps)

cat("\n", strrep("═", 70), "\n")
cat("2b. Régression linéaire — Modèle réduit (base théorique)\n")
cat(strrep("═", 70), "\n")
print(summary(lm_reduit))


# ═══════════════════════════════════════════════════════════════════════════════
# 3.  ÉTUDE DE LA COLINÉARITÉ (préalable à la modélisation)
# ═══════════════════════════════════════════════════════════════════════════════
# Équivalent SAS : PROC REG / vif tol collin ; PROC CORR ;

# 3a. VIF et Tolérance
cat("\n", strrep("═", 70), "\n")
cat("3a. VIF et Tolérance\n")
cat(strrep("═", 70), "\n")
vif_vals <- car::vif(lm_complet)
cat("VIF :\n")
print(round(vif_vals, 4))
cat("\nTolérance = 1/VIF :\n")
print(round(1 / vif_vals, 4))

# 3b. Matrice de corrélation entre les prédicteurs
cat("\n", strrep("═", 70), "\n")
cat("3b. Matrice de corrélation — Variables explicatives quantitatives\n")
cat(strrep("═", 70), "\n")
vars_pred <- c("age", "revenus_mensuels_euros", "depenses_sante_annuelles_euros",
               "nombre_consultations_annuelles", "nombre_medicaments_reguliers",
               "imc", "nombre_enfants")
cor_mat <- cor(esps[, vars_pred], use = "complete.obs")
print(round(cor_mat, 3))

corrplot::corrplot(cor_mat, method = "color", type = "upper",
                   tl.cex = 0.75, addCoef.col = "black", number.cex = 0.6,
                   title = "Matrice de corrélation — Variables quantitatives",
                   mar = c(0, 0, 1.5, 0))

# 3c. Indice de conditionnement
#     Équivalent SAS : PROC REG / collin ;  (condition index = max/min valeur singulière)
cat("\n", strrep("═", 70), "\n")
cat("3c. Indice de conditionnement\n")
cat(strrep("═", 70), "\n")
X_mat  <- model.matrix(lm_complet)
sv     <- svd(X_mat)$d
ci_max <- max(sv) / min(sv)
cat(sprintf("Condition number (rapport max/min valeurs singulières) : %.2f\n", ci_max))
cat("Règle : > 30 → colinéarité sévère\n")


# ═══════════════════════════════════════════════════════════════════════════════
# 4.  SÉLECTION AUTOMATIQUE — VÉRIFICATION DE COHÉRENCE UNIQUEMENT
# ═══════════════════════════════════════════════════════════════════════════════
# IMPORTANT : critère primaire = théorie (Grossman, 1972 ; Harrell, 2001).
# Ces procédures sont des outils de VÉRIFICATION DE COHÉRENCE seulement.
# En cas de divergence théorie/données, la théorie prime.

formula_full <- score_sante ~ age + revenus_mensuels_euros +
  depenses_sante_annuelles_euros + nombre_consultations_annuelles +
  nombre_medicaments_reguliers + imc + nombre_enfants

lm_full_sel <- lm(formula_full, data = esps)
lm_null_sel <- lm(score_sante ~ 1, data = esps)

# 4a. Tous sous-modèles — R² ajusté (équivalent SAS : selection = ADJRSQ best = 5)
cat("\n", strrep("═", 70), "\n")
cat("4a. Sélection — Tous sous-modèles (R² ajusté, AIC, BIC)\n")
cat(strrep("═", 70), "\n")
reg_sub <- leaps::regsubsets(formula_full, data = esps, nvmax = 7)
reg_sum <- summary(reg_sub)
cat("R² ajusté par nombre de variables :\n")
print(round(reg_sum$adjr2, 4))
best5 <- order(reg_sum$adjr2, decreasing = TRUE)[1:5]
cat("\nTop 5 modèles (R² ajusté) — variables incluses :\n")
print(reg_sum$which[best5, ])

# 4b. Sélection ascendante (forward)
#     Équivalent SAS : PROC REG / selection = forward slentry = 0.05 ;
cat("\n", strrep("═", 70), "\n")
cat("4b. Sélection Forward (critère AIC, equivalent slentry = 0.05)\n")
cat(strrep("═", 70), "\n")
lm_forward <- step(lm_null_sel,
                   scope = list(lower = lm_null_sel, upper = lm_full_sel),
                   direction = "forward", trace = 1)
print(summary(lm_forward))

# 4c. Sélection descendante (backward)
#     Équivalent SAS : PROC REG / selection = backward slstay = 0.05 ;
cat("\n", strrep("═", 70), "\n")
cat("4c. Sélection Backward (critère AIC)\n")
cat(strrep("═", 70), "\n")
lm_backward <- step(lm_full_sel, direction = "backward", trace = 1)
print(summary(lm_backward))

# 4d. Sélection pas à pas (stepwise) — VÉRIFICATION DE COHÉRENCE SEULEMENT
#     Équivalent SAS : PROC REG / selection = stepwise slentry = 0.05 slstay = 0.05 ;
cat("\n", strrep("═", 70), "\n")
cat("4d. Sélection Stepwise — VÉRIFICATION DE COHÉRENCE SEULEMENT\n")
cat(strrep("═", 70), "\n")
lm_stepwise <- step(lm_null_sel,
                    scope = list(lower = lm_null_sel, upper = lm_full_sel),
                    direction = "both", trace = 1)
print(summary(lm_stepwise))


# ═══════════════════════════════════════════════════════════════════════════════
# 5.  VALIDATION DU MODÈLE LINÉAIRE (robustesse)
# ═══════════════════════════════════════════════════════════════════════════════
# Ces diagnostics s'appliquent au modèle linéaire (robustesse — §2).
# Le modèle PRINCIPAL (§7) est validé par le Score Test (§7b) et la k-fold (§5k).
# Équivalent SAS : PROC REG r spec dwprob + PROC UNIVARIATE normal qqplot

# 5a. Export des résidus (équivalent OUTPUT out = ; rstudent / predicted / residual / cookd / h)
resid_df <- data.frame(
  resid    = residuals(lm_reduit),
  yhat     = fitted(lm_reduit),
  rstud    = rstudent(lm_reduit),
  cooksd   = cooks.distance(lm_reduit),
  leverage = hatvalues(lm_reduit)
)

# 5b. Normalité des résidus — QQ-plot (équivalent PROC UNIVARIATE qqplot)
cat("\n--- 5b. Normalité des résidus — Test de Shapiro-Wilk ---\n")
qqnorm(resid_df$resid, main = "QQ-plot des résidus (modèle réduit)")
qqline(resid_df$resid, col = "red", lwd = 2)
print(shapiro.test(resid_df$resid))

# 5c. Normalité — Histogramme (équivalent PROC UNIVARIATE histogram / normal)
hist(resid_df$resid, breaks = 25, probability = TRUE,
     main = "Histogramme des résidus (modèle réduit)",
     xlab = "Résidus", col = "steelblue", border = "white")
curve(dnorm(x, mean = 0, sd = sd(resid_df$resid)),
      add = TRUE, col = "red", lwd = 2)

# 5d. Éléments aberrants — RStudent × Leverage
#     Équivalent SAS : PROC REG plots(only label) = (RStudentByLeverage)
plot(resid_df$leverage, resid_df$rstud,
     xlab = "Leverage (h_ii)", ylab = "Résidu studentisé (RStudent)",
     main = "Éléments aberrants — RStudent × Leverage",
     pch = 19, cex = 0.7, col = "steelblue")
abline(h = c(-2, 2), lty = 2, col = "red")
abline(v = 2 * mean(resid_df$leverage), lty = 2, col = "orange")

# 5e. Distance de Cook (seuil : D_i > 4/n = 4/500 = 0.008)
#     Équivalent SAS : PROC REG plots(only label) = (CooksD)
threshold_cook <- 4 / nrow(esps)
cat(sprintf("\n--- 5e. Seuil Cook = 4/n = 4/%d = %.4f ---\n",
            nrow(esps), threshold_cook))
plot(resid_df$cooksd, type = "h",
     xlab = "Indice", ylab = "Distance de Cook",
     main = "Distance de Cook — Observations influentes")
abline(h = threshold_cook, col = "red", lty = 2)

# 5f. Indépendance — Test de Durbin-Watson
#     Équivalent SAS : PROC REG / dwprob
cat("\n--- 5f. Durbin-Watson ---\n")
print(lmtest::dwtest(lm_reduit))

# 5g. Homoscédasticité — Test de White (équivalent SAS : PROC REG / spec)
#     R : bptest() avec termes croisés reproduit le test de White
cat("\n--- 5g. Test de White (Breusch-Pagan avec HC) ---\n")
print(lmtest::bptest(lm_reduit, studentize = FALSE))

# 5h. Linéarité — Résidus partiels (Added-Variable Plots)
#     Équivalent SAS : PROC REG plots(only) = (partialplot)
car::avPlots(lm_reduit,
             main = "Résidus partiels (Added-Variable Plots)")

# 5i. Visualisation LOESS
#     Équivalent SAS : PROC SGPLOT loess y = score_sante x = ...
for (v in c("age", "nombre_consultations_annuelles",
            "nombre_medicaments_reguliers")) {
  p <- ggplot(esps, aes(x = .data[[v]], y = score_sante)) +
    geom_point(alpha = 0.3, size = 1) +
    geom_smooth(method = "loess", se = TRUE, color = "red") +
    labs(x = v, y = "score_sante",
         title = paste("LOESS — score_sante vs", v)) +
    theme_minimal(base_size = 10)
  print(p)
}

# 5j. Observations potentiellement aberrantes / influentes
#     Équivalent SAS : PROC PRINT ; where abs(rstud) > 2 or cooksd > 0.008 ;
cat("\n--- 5j. Observations aberrantes (|rstud| > 2 OU Cook > 4/n) ---\n")
idx_out <- which(abs(resid_df$rstud) > 2 | resid_df$cooksd > threshold_cook)
if (length(idx_out) > 0) {
  print(cbind(
    esps[idx_out, c("id", "age", "score_sante")],
    round(resid_df[idx_out, c("yhat", "resid", "rstud", "cooksd", "leverage")], 4)
  ))
} else {
  cat("Aucune observation aberrante détectée selon les seuils.\n")
}


# ─────────────────────────────────────────────────────────────────────────────
# 5k. VALIDATION CROISÉE K-FOLD (k = 10) — Modèle logistique ordinal PRINCIPAL
#     Équivalent SAS : macro %kfold_ordinal (PROC SURVEYSELECT + boucle %do)
#     Note : MASS::polr() = équivalent exact de PROC LOGISTIC / link = cumlogit
# ─────────────────────────────────────────────────────────────────────────────
cat("\n", strrep("═", 70), "\n")
cat("5k. Validation croisée k-fold (k = 10) — Modèle logistique ordinal\n")
cat(strrep("═", 70), "\n")

set.seed(42)       # reproductibilité (équivalent seed = 42 dans PROC SURVEYSELECT)
k <- 10L
n <- nrow(esps)

# Partition stratifiée par etat_sante_percu (équivalent : strata etat_sante_percu)
folds <- rep(NA_integer_, n)
for (lev in levels(esps$etat_sante_percu)) {
  idx <- which(as.character(esps$etat_sante_percu) == lev)
  idx_shuffled <- sample(idx)
  folds[idx_shuffled] <- (seq_along(idx_shuffled) - 1L) %% k + 1L
}

concordance_folds <- numeric(k)

for (i in seq_len(k)) {
  train_data <- esps[folds != i, ]
  test_data  <- esps[folds == i, ]

  # Entraîner sur les (k-1) folds
  fit_fold <- MASS::polr(
    etat_sante_percu ~ age + nombre_consultations_annuelles +
      nombre_medicaments_reguliers + sexe + hospitalisation_12_mois +
      activite_physique + handicap_declare,
    data = train_data, Hess = TRUE, method = "logistic"
  )

  # Prédire sur le fold de test
  pred_class <- predict(fit_fold, newdata = test_data)
  concordance_folds[i] <- mean(pred_class == test_data$etat_sante_percu)
  cat(sprintf("  Fold %2d : taux de concordance = %.4f\n", i, concordance_folds[i]))
}

cat(sprintf("\nTaux de concordance moyen : %.4f\n", mean(concordance_folds)))
cat(sprintf("Écart-type               : %.4f\n", sd(concordance_folds)))
cat(sprintf("IC 95%% approximatif      : [%.4f ; %.4f]\n",
            mean(concordance_folds) - 1.96 * sd(concordance_folds) / sqrt(k),
            mean(concordance_folds) + 1.96 * sd(concordance_folds) / sqrt(k)))


# ═══════════════════════════════════════════════════════════════════════════════
# 6.  ROBUSTESSE — ANALYSE DE COVARIANCE (ANCOVA, modèle alternatif)
# ═══════════════════════════════════════════════════════════════════════════════
# Estimé À TITRE DE ROBUSTESSE. Conclusions comparées au modèle ordinal (§7).
# Équivalent SAS : PROC GLM CLASS ... ; model score_sante = ... / solution ss3 ;
#                  LSMEANS / pdiff adjust = tukey ;

# Recodages de référence (identiques aux ref = "..." de SAS)
esps$sexe                    <- relevel(esps$sexe, ref = "Homme")
esps$hospitalisation_12_mois <- relevel(esps$hospitalisation_12_mois, ref = "Non")
esps$tabagisme               <- relevel(esps$tabagisme, ref = "Non-fumeur")
esps$activite_physique       <- relevel(esps$activite_physique, ref = "Sédentaire")
esps$handicap_declare        <- relevel(esps$handicap_declare, ref = "Non")
esps$couverture_complementaire <- relevel(esps$couverture_complementaire,
                                           ref = "Mutuelle privée")

# 6a. ANCOVA complète (équivalent PROC GLM complet + /ss3)
lm_ancova_complet <- lm(
  score_sante ~ age + revenus_mensuels_euros + imc +
    depenses_sante_annuelles_euros + nombre_consultations_annuelles +
    nombre_medicaments_reguliers +
    sexe + profession + couverture_complementaire +
    hospitalisation_12_mois + tabagisme + activite_physique +
    handicap_declare + maladies_declarees,
  data = esps
)
cat("\n", strrep("═", 70), "\n")
cat("6a. ANCOVA complète — SS de type III\n")
cat(strrep("═", 70), "\n")
print(car::Anova(lm_ancova_complet, type = "III"))

# 6b. ANCOVA réduite — facteurs significatifs (base théorique)
lm_ancova_reduit <- lm(
  score_sante ~ age + nombre_consultations_annuelles +
    nombre_medicaments_reguliers +
    sexe + hospitalisation_12_mois + activite_physique + handicap_declare,
  data = esps
)
cat("\n", strrep("═", 70), "\n")
cat("6b. ANCOVA réduite — SS de type III + coefficients\n")
cat(strrep("═", 70), "\n")
print(car::Anova(lm_ancova_reduit, type = "III"))
print(summary(lm_ancova_reduit))

# LSMEANS + comparaisons de Tukey
# Équivalent SAS : LSMEANS sexe hospit ... / pdiff adjust = tukey
cat("\n--- Moyennes marginales estimées (équiv. LSMEANS) + Tukey ---\n")
for (fac in c("sexe", "hospitalisation_12_mois", "activite_physique", "handicap_declare")) {
  cat("\n---", fac, "---\n")
  em  <- emmeans::emmeans(lm_ancova_reduit, specs = fac)
  print(pairs(em, adjust = "tukey"))
}

# Graphique des LSMEANS (équivalent visualisation SAS)
p_lsmeans <- ggplot(
  as.data.frame(emmeans::emmeans(lm_ancova_reduit, "activite_physique")),
  aes(x = reorder(activite_physique, emmean), y = emmean,
      ymin = lower.CL, ymax = upper.CL, color = activite_physique)
) +
  geom_point(size = 3) +
  geom_errorbar(width = 0.2, linewidth = 1) +
  labs(x = "Activité physique", y = "Score santé estimé (LSMEANS)",
       title = "Moyennes marginales estimées — Activité physique") +
  theme_minimal() +
  theme(legend.position = "none")
print(p_lsmeans)

# 6c. Test d'interaction Âge × Sexe (équivalent SAS : model age*sexe / ss3)
lm_interaction <- lm(score_sante ~ age + sexe + age:sexe, data = esps)
cat("\n--- 6c. Test d'interaction Âge × Sexe (SS de type III) ---\n")
print(car::Anova(lm_interaction, type = "III"))


# ═══════════════════════════════════════════════════════════════════════════════
# 7.  MODÈLE PRINCIPAL — RÉGRESSION LOGISTIQUE ORDINALE
# ═══════════════════════════════════════════════════════════════════════════════
# Modèle PRINCIPAL (McCullagh, 1980 ; Agresti, 2010).
# Variables sélectionnées sur base THÉORIQUE (Grossman, 1972 ; Harrell, 2001).
# Équivalent SAS : PROC LOGISTIC / link = cumlogit rsquare lackfit stb
# MASS::polr() modélise P(Y ≤ j) pour j = 1,2,3,4 — même convention que SAS

# 7a. Modèle ordinal complet
polr_complet <- MASS::polr(
  etat_sante_percu ~ age + revenus_mensuels_euros + imc +
    nombre_consultations_annuelles + nombre_medicaments_reguliers +
    depenses_sante_annuelles_euros + sexe + hospitalisation_12_mois +
    tabagisme + activite_physique + handicap_declare + couverture_complementaire,
  data = esps, Hess = TRUE, method = "logistic"
)

cat("\n", strrep("═", 70), "\n")
cat("7a. Régression logistique ordinale — Modèle complet\n")
cat(strrep("═", 70), "\n")
print(summary(polr_complet))

# Odds Ratios (exp des coefficients — équivalent OR dans les sorties SAS)
cat("\nOdds Ratios (exp coef) :\n")
print(round(exp(coef(polr_complet)), 4))

# IC à 95 % des OR
ci_or <- exp(confint(polr_complet))
cat("\nIC 95% des Odds Ratios :\n")
print(round(ci_or, 4))

# Pseudo-R² de Nagelkerke (équivalent option rsquare de SAS)
ll_null_polr  <- logLik(MASS::polr(etat_sante_percu ~ 1, data = esps,
                                   method = "logistic", Hess = FALSE))
ll_model_polr <- logLik(polr_complet)
n_obs         <- nrow(esps)
r2_nag <- (1 - exp((2 / n_obs) * (as.numeric(ll_null_polr) -
                                    as.numeric(ll_model_polr)))) /
  (1 - exp((2 / n_obs) * as.numeric(ll_null_polr)))
cat(sprintf("\nPseudo-R² de Nagelkerke : %.4f\n", r2_nag))

# AIC / BIC
cat(sprintf("AIC = %.2f   BIC = %.2f\n", AIC(polr_complet), BIC(polr_complet)))

# ─────────────────────────────────────────────────────────────────────────────
# 7b. Test de proportionnalité des odds (Score Test)
#     H₀ : odds ratios constants sur l'ensemble des seuils de coupure.
#     Si p-value < 0.05 → hypothèse violée → modèle partial proportional odds.
#     Équivalent SAS : "Score Test for the Proportional Odds Assumption" dans
#                      la sortie PROC LOGISTIC.
#     R : package brant (Brant, 1990)
# ─────────────────────────────────────────────────────────────────────────────
cat("\n", strrep("═", 70), "\n")
cat("7b. Test de proportionnalité des odds (Brant Test)\n")
cat(strrep("═", 70), "\n")
if (requireNamespace("brant", quietly = TRUE)) {
  print(brant::brant(polr_complet))
} else {
  cat("Installer le package 'brant' pour le test de proportionnalité :\n")
  cat("  install.packages('brant')\n")
}

# ─────────────────────────────────────────────────────────────────────────────
# 7c. Modèle ordinal réduit — MODÈLE PRINCIPAL FINAL
#     Variables retenues sur base THÉORIQUE (Grossman, 1972 ; Harrell, 2001)
#     Équivalent SAS : PROC LOGISTIC réduit / link = cumlogit rsquare lackfit stb
# ─────────────────────────────────────────────────────────────────────────────
polr_reduit <- MASS::polr(
  etat_sante_percu ~ age + nombre_consultations_annuelles +
    nombre_medicaments_reguliers + sexe + hospitalisation_12_mois +
    activite_physique + handicap_declare,
  data = esps, Hess = TRUE, method = "logistic"
)

cat("\n", strrep("═", 70), "\n")
cat("7c. Régression logistique ordinale — Modèle réduit (PRINCIPAL FINAL)\n")
cat(strrep("═", 70), "\n")
print(summary(polr_reduit))

cat("\nOdds Ratios :\n")
print(round(exp(coef(polr_reduit)), 4))

cat("\nIC 95% des Odds Ratios :\n")
print(round(exp(confint(polr_reduit)), 4))

r2_nag_reduit <- (1 - exp((2 / n_obs) * (as.numeric(ll_null_polr) -
                                            as.numeric(logLik(polr_reduit))))) /
  (1 - exp((2 / n_obs) * as.numeric(ll_null_polr)))
cat(sprintf("Pseudo-R² de Nagelkerke : %.4f\n", r2_nag_reduit))
cat(sprintf("AIC = %.2f   BIC = %.2f\n", AIC(polr_reduit), BIC(polr_reduit)))

# ─────────────────────────────────────────────────────────────────────────────
# 7d. Régression logistique BINAIRE (modèle de robustesse)
#     Variable réponse : sante_mauvaise (0/1)
#     Estimé À TITRE DE ROBUSTESSE. Comparé à 7c pour tester H3.
#     Équivalent SAS : PROC LOGISTIC model sante_mauvaise (event="1") = ...
#                      / rsquare lackfit ctable stb
# ─────────────────────────────────────────────────────────────────────────────
logit_bin <- glm(
  sante_mauvaise ~ age + revenus_mensuels_euros + imc +
    nombre_consultations_annuelles + nombre_medicaments_reguliers +
    sexe + hospitalisation_12_mois + tabagisme + activite_physique +
    handicap_declare,
  data = esps, family = binomial(link = "logit")
)

cat("\n", strrep("═", 70), "\n")
cat("7d. Régression logistique binaire (robustesse)\n")
cat(strrep("═", 70), "\n")
print(summary(logit_bin))

cat("\nOdds Ratios :\n")
print(round(exp(coef(logit_bin)), 4))

cat("\nIC 95% des OR :\n")
print(round(exp(confint(logit_bin)), 4))

# Table de classement (ctable dans SAS)
pred_bin <- ifelse(predict(logit_bin, type = "response") >= 0.5, 1, 0)
cat("\nMatrice de confusion (seuil = 0.5) :\n")
conf_mat <- table(Observé = esps$sante_mauvaise, Prédit = pred_bin)
print(conf_mat)
cat(sprintf("Taux de classement global : %.1f%%\n",
            mean(pred_bin == esps$sante_mauvaise) * 100))

# ─────────────────────────────────────────────────────────────────────────────
# 7e. COHÉRENCE — Sélection stepwise sur modèle ordinal (vérification)
#     IMPORTANT : critère primaire = théorie. Stepwise = vérification seulement.
#     Équivalent SAS : PROC LOGISTIC / link = cumlogit selection = stepwise
# ─────────────────────────────────────────────────────────────────────────────
cat("\n", strrep("═", 70), "\n")
cat("7e. Cohérence stepwise — Logistique ordinale (vérification uniquement)\n")
cat(strrep("═", 70), "\n")
polr_step <- MASS::stepAIC(polr_complet, direction = "both", trace = 1)
print(summary(polr_step))

# ─────────────────────────────────────────────────────────────────────────────
# 7f. Courbe ROC (régression binaire)
#     Équivalent SAS : PROC LOGISTIC plots(only) = (roc effect oddsratio)
# ─────────────────────────────────────────────────────────────────────────────
logit_bin_reduit <- glm(
  sante_mauvaise ~ age + nombre_consultations_annuelles +
    nombre_medicaments_reguliers + sexe + hospitalisation_12_mois +
    activite_physique + handicap_declare,
  data = esps, family = binomial(link = "logit")
)

roc_obj <- pROC::roc(
  esps$sante_mauvaise,
  predict(logit_bin_reduit, type = "response"),
  quiet = TRUE
)

cat(sprintf("\n--- 7f. Courbe ROC — AUC = %.4f ---\n", pROC::auc(roc_obj)))
plot(roc_obj,
     main = paste("Courbe ROC — AUC =", round(pROC::auc(roc_obj), 4)),
     col = "steelblue", lwd = 2)
abline(a = 0, b = 1, lty = 2, col = "grey")

# 7g. Matrice de confusion finale (équivalent : ctable + interprétation)
pred_bin_red <- ifelse(predict(logit_bin_reduit, type = "response") >= 0.5, 1, 0)
conf_final <- table(Observé = esps$sante_mauvaise, Prédit = pred_bin_red)
cat("\n--- 7g. Matrice de confusion — Modèle binaire réduit ---\n")
print(conf_final)

TP <- conf_final[2, 2]; FN <- conf_final[2, 1]
TN <- conf_final[1, 1]; FP <- conf_final[1, 2]
cat(sprintf("Sensibilité  : %.1f%%\n", TP / (TP + FN) * 100))
cat(sprintf("Spécificité  : %.1f%%\n", TN / (TN + FP) * 100))
cat(sprintf("Taux global  : %.1f%%\n", (TP + TN) / sum(conf_final) * 100))

###############################################################################
# FIN DE L'ANNEXE C
###############################################################################
