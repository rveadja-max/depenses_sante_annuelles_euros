#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Génération d'une base de données synthétique au format CSV
inspirée de l'Enquête Santé et Protection Sociale (ESPS) — IRDES.

Méthodologie : enquête en coupe transversale (cross-sectional survey)
Observations  : individus résidant en France métropolitaine
Variables     : 25 (> 20), quantitatives et qualitatives

Source de référence : IRDES — Enquête Santé et Protection Sociale (ESPS)
https://www.irdes.fr/recherche/enquetes/esps-enquete-sur-la-sante-et-la-protection-sociale/
"""

import csv
import random
import os

# ── Configuration ────────────────────────────────────────────────────────────
SEED = 42
N = 500  # nombre d'observations (individus)
OUTPUT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                      "base_esps_synthétique.csv")

random.seed(SEED)

# ── Modalités des variables qualitatives ─────────────────────────────────────
SEXE = ["Homme", "Femme"]
PROFESSIONS = [
    "Agriculteur", "Artisan/Commerçant", "Cadre supérieur",
    "Profession intermédiaire", "Employé", "Ouvrier",
    "Retraité", "Sans activité professionnelle", "Étudiant"
]
STATUT_ASSURANCE = [
    "Régime général", "MSA", "RSI/SSI",
    "Régime spécial", "Autre régime"
]
ETAT_SANTE_PERCU = [
    "Très bon", "Bon", "Assez bon", "Mauvais", "Très mauvais"
]
MALADIES = [
    "Aucune", "Diabète", "Hypertension", "Asthme", "Dépression",
    "Lombalgie chronique", "Arthrose", "Cardiopathie",
    "Cancer (rémission)", "Maladie respiratoire chronique",
    "Trouble anxieux", "Migraine chronique", "Obésité morbide"
]
NIVEAU_EDUCATION = [
    "Sans diplôme", "CAP/BEP", "Baccalauréat",
    "Bac+2", "Bac+3/Licence", "Bac+5/Master", "Doctorat"
]
SITUATION_FAMILIALE = [
    "Célibataire", "Marié(e)", "Pacsé(e)",
    "Divorcé(e)", "Veuf/Veuve"
]
REGIONS = [
    "Île-de-France", "Auvergne-Rhône-Alpes", "Nouvelle-Aquitaine",
    "Occitanie", "Hauts-de-France", "Provence-Alpes-Côte d'Azur",
    "Grand Est", "Pays de la Loire", "Bretagne",
    "Normandie", "Bourgogne-Franche-Comté", "Centre-Val de Loire",
    "Corse"
]
TYPE_COMMUNE = ["Rurale", "Urbaine petite", "Urbaine moyenne", "Métropole"]
TABAGISME = ["Non-fumeur", "Ancien fumeur", "Fumeur occasionnel", "Fumeur quotidien"]
CONSOMMATION_ALCOOL = ["Jamais", "Occasionnelle", "Régulière", "Quotidienne"]
ACTIVITE_PHYSIQUE = [
    "Sédentaire", "Activité légère", "Activité modérée", "Activité intense"
]
COUVERTURE_COMPLEMENTAIRE = [
    "Mutuelle privée", "Complémentaire santé solidaire (CSS)",
    "Assurance privée", "Aucune complémentaire"
]
RENONCEMENT_SOINS = ["Oui", "Non"]
HOSPITALISATION = ["Oui", "Non"]
HANDICAP_DECLARE = ["Oui", "Non"]
SATISFACTION_SYSTEME = [
    "Très satisfait", "Satisfait", "Peu satisfait", "Pas du tout satisfait"
]
# ── En-têtes (25 variables) ─────────────────────────────────────────────────
HEADERS = [
    "id",                              #  1  identifiant unique
    "age",                             #  2  quantitative
    "sexe",                            #  3  qualitative
    "profession",                      #  4  qualitative
    "niveau_education",                #  5  qualitative
    "situation_familiale",             #  6  qualitative
    "nombre_enfants",                  #  7  quantitative
    "region",                          #  8  qualitative
    "type_commune",                    #  9  qualitative
    "revenus_mensuels_euros",          # 10  quantitative
    "statut_assurance",                # 11  qualitative
    "couverture_complementaire",       # 12  qualitative
    "depenses_sante_annuelles_euros",  # 13  quantitative
    "nombre_consultations_annuelles",  # 14  quantitative
    "nombre_medicaments_reguliers",    # 15  quantitative
    "hospitalisation_12_mois",         # 16  qualitative
    "etat_sante_percu",               # 17  qualitative
    "maladies_declarees",             # 18  qualitative
    "imc",                             # 19  quantitative
    "tabagisme",                       # 20  qualitative
    "consommation_alcool",            # 21  qualitative
    "activite_physique",              # 22  qualitative
    "handicap_declare",               # 23  qualitative
    "renoncement_soins_12_mois",      # 24  qualitative
    "satisfaction_systeme_soins",     # 25  qualitative
]


def generate_individual(ind_id: int) -> list:
    """Génère une observation (un individu) avec des valeurs réalistes."""
    age = random.randint(18, 95)
    sexe = random.choice(SEXE)

    # Profession cohérente avec l'âge
    if age >= 65:
        profession = random.choices(
            ["Retraité", "Sans activité professionnelle"],
            weights=[85, 15]
        )[0]
    elif age <= 25:
        profession = random.choices(
            PROFESSIONS,
            weights=[1, 2, 3, 5, 15, 10, 0, 14, 50]
        )[0]
    else:
        profession = random.choices(
            PROFESSIONS,
            weights=[3, 7, 15, 18, 22, 15, 2, 13, 5]
        )[0]

    niveau_education = random.choices(
        NIVEAU_EDUCATION,
        weights=[10, 20, 20, 15, 15, 15, 5]
    )[0]

    situation_familiale = random.choices(
        SITUATION_FAMILIALE,
        weights=[25, 40, 10, 15, 10] if age >= 30 else [60, 15, 10, 5, 0]
    )[0]

    nombre_enfants = random.choices(
        range(6), weights=[30, 25, 25, 12, 5, 3]
    )[0]

    region = random.choices(
        REGIONS,
        weights=[20, 13, 10, 9, 9, 8, 8, 6, 5, 5, 3, 3, 1]
    )[0]

    type_commune = random.choices(
        TYPE_COMMUNE, weights=[20, 25, 30, 25]
    )[0]

    # Revenus (corrélés à la profession/éducation)
    base_revenu = {
        "Agriculteur": 1400, "Artisan/Commerçant": 2000,
        "Cadre supérieur": 3800, "Profession intermédiaire": 2600,
        "Employé": 1700, "Ouvrier": 1500,
        "Retraité": 1500, "Sans activité professionnelle": 800,
        "Étudiant": 600
    }
    revenus = max(0, int(random.gauss(
        base_revenu.get(profession, 1500), 500
    )))

    statut_assurance = random.choices(
        STATUT_ASSURANCE, weights=[70, 8, 7, 10, 5]
    )[0]

    couverture_complementaire = random.choices(
        COUVERTURE_COMPLEMENTAIRE, weights=[55, 15, 20, 10]
    )[0]

    # Dépenses de santé (corrélées à l'âge)
    depenses_base = 400 + age * 25 + random.gauss(0, 300)
    depenses_sante = max(0, round(depenses_base, 2))

    # Consultations (corrélées à l'âge et l'état de santé)
    nb_consult_base = max(0, int(2 + age / 20 + random.gauss(0, 2)))
    nombre_consultations = min(nb_consult_base, 30)

    nombre_medicaments = max(0, int(random.gauss(age / 25, 1.5)))

    hospitalisation = random.choices(
        HOSPITALISATION,
        weights=[15 + age / 5, 85 - age / 5]
    )[0]

    # État de santé perçu (corrélé à l'âge)
    if age < 40:
        etat_sante = random.choices(
            ETAT_SANTE_PERCU, weights=[30, 40, 20, 8, 2]
        )[0]
    elif age < 65:
        etat_sante = random.choices(
            ETAT_SANTE_PERCU, weights=[15, 35, 30, 15, 5]
        )[0]
    else:
        etat_sante = random.choices(
            ETAT_SANTE_PERCU, weights=[5, 20, 35, 25, 15]
        )[0]

    maladies = random.choices(
        MALADIES,
        weights=[40, 8, 10, 5, 7, 5, 5, 4, 2, 4, 4, 4, 2]
    )[0]

    # IMC (distribution réaliste, moyenne ~25)
    imc = round(max(15, min(50, random.gauss(25.5, 4.5))), 1)

    tabagisme = random.choices(
        TABAGISME, weights=[40, 25, 10, 25]
    )[0]

    consommation_alcool = random.choices(
        CONSOMMATION_ALCOOL, weights=[20, 40, 25, 15]
    )[0]

    activite_physique = random.choices(
        ACTIVITE_PHYSIQUE, weights=[25, 30, 30, 15]
    )[0]

    handicap = random.choices(
        HANDICAP_DECLARE,
        weights=[10 + age / 5, 90 - age / 5]
    )[0]

    renoncement = random.choices(
        RENONCEMENT_SOINS,
        weights=[25 if revenus < 1200 else 10, 75 if revenus < 1200 else 90]
    )[0]

    satisfaction = random.choices(
        SATISFACTION_SYSTEME, weights=[15, 45, 30, 10]
    )[0]

    return [
        ind_id,
        age,
        sexe,
        profession,
        niveau_education,
        situation_familiale,
        nombre_enfants,
        region,
        type_commune,
        revenus,
        statut_assurance,
        couverture_complementaire,
        depenses_sante,
        nombre_consultations,
        nombre_medicaments,
        hospitalisation,
        etat_sante,
        maladies,
        imc,
        tabagisme,
        consommation_alcool,
        activite_physique,
        handicap,
        renoncement,
        satisfaction,
    ]


def main():
    """Point d'entrée principal : génère et écrit le CSV."""
    rows = [generate_individual(i + 1) for i in range(N)]

    with open(OUTPUT, "w", newline="", encoding="utf-8") as csvfile:
        writer = csv.writer(csvfile, delimiter=";")
        writer.writerow(HEADERS)
        writer.writerows(rows)

    print(f"✅ Base de données générée : {OUTPUT}")
    print(f"   — {N} observations (individus)")
    print(f"   — {len(HEADERS)} variables")
    print(f"   — Séparateur : point-virgule (;)")


if __name__ == "__main__":
    main()
