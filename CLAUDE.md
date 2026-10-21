# Contexte du projet

Je suis Komlavi, étudiant en Master 2 Data Science (Lille). Je passe un test technique pour un stage "Analytics Engineering" chez Equancy. Livrable : un dashboard Power BI à rendre le mardi 27 octobre 2026, suivi d'un entretien le lendemain où je dois expliquer chaque choix.

## Sujet du test
Je suis le responsable logistique d'une entreprise internationale qui choisit une nouvelle zone d'implantation. À partir de 8 fichiers CSV (pays, dates, population, PIB, indicateurs démographiques, émissions de CO2, dépenses d'éducation, dépenses de préservation du patrimoine), je dois présenter les données à mon manager et répondre à trois questions :
a) Quels pays ont la plus forte croissance du PIB entre deux années données ?
b) Quelle est la corrélation entre les émissions de CO2 et le niveau d'éducation entre pays ?
c) Quels pays ont la plus faible empreinte carbone par habitant, et comment évolue-t-elle au fil des années ?
L'énoncé invite à prendre des hypothèses. Tout ce qui n'est pas dans l'énoncé est une hypothèse de ma part, à signaler comme telle.
L'énoncé ne précise pas combien de pays retenir. Hypothèse de travail (H22, à valider) : présenter une présélection de pays argumentée à partir des trois analyses, plutôt qu'un seul pays.

## Pipeline
CSV (Python/pandas) -> PostgreSQL (schémas raw, staging, marts) -> dbt Core -> Power BI.
- raw : copie fidèle des CSV, jamais modifiée.
- staging : une vue par fichier (typage, renommage). 39 tests dbt (38 réussis, 1 alerte volontaire).
- marts : dim_country, faits, un mart par question. Pas encore construit.
- Base : equancy_test. Python 3.12 dans .venv, dbt 1.13 beta, adaptateur postgres, dbt_utils 1.4.1.

## Décisions déjà prises (détail dans docs/hypotheses.md)
- Un "pays" est un État souverain (195). Territoires et agrégats sont gardés mais exclus des classements (seed country_classification, 241 lignes).
- Jointures sur le code ISO alpha-3, jamais sur le nom.
- Valeurs manquantes : on garde NULL, jamais de remplacement par zéro ou moyenne.
- La période est l'année entière (entier), pas une date.
- Le fichier patrimoine est exclu (113 doublons pays-année).
- Entité "St. Kitts-Nevis-Anguilla" exclue du fichier émissions (code KNA partagé).
- Période d'étude commune aux trois questions : 2010-2021 (H21), appliquée dans les marts. Pour b, la corrélation repose en pratique sur 2010-2018 (l'éducation s'effondre après), limite annoncée. Les tables de faits gardent une période plus large : PIB et population 2000-2021, émissions 1950-2021.
- Éducation approchée par la dépense publique d'éducation par habitant (limite à annoncer : mesure un effort, pas un niveau).
- Unités déduites : PIB en dollars US, émissions en MtCO2, population en milliers, éducation en millions de dollars constants.
- Une table de couverture (pays x variable) doit rendre visibles les pays absents.

## Façon de répondre
- Réponds en français.
- Donne le code complet, prêt à être utilisé.
- Le code doit être compréhensible, de niveau académique : un commentaire en français pour chaque étape importante, des noms de colonnes explicites, des CTE nommées plutôt que des sous-requêtes imbriquées.
- Après chaque code, explique en quelques phrases la logique, les hypothèses et les limites, comme je le ferais à l'oral en entretien.
- Un seul modèle ou une seule étape à la fois, puis la commande pour le lancer et ce que je dois voir.
- Ajoute les tests dbt adaptés (unique, not_null, relationships, accepted_values) et dis ce qu'ils prouvent.

## Règles de nettoyage (à respecter à chaque modèle)
- Ne jamais modifier raw. Tout le nettoyage se fait en staging puis en marts.
- Chaque règle de nettoyage est documentée (pourquoi, combien de lignes touchées) et testée avec dbt.
- Jamais d'imputation : NULL reste NULL.
- Après chaque modèle de faits, vérifier : unicité pays-année, présence du code dans dim_country, plages de valeurs plausibles, nombre de pays par année.
- Signaler toute valeur aberrante avant de la retirer, et dire pourquoi.

## Sécurité
- Ne lis, n'affiche et ne copie jamais .env ni profiles.yml (mots de passe).
- Ne lance pas de commande qui supprime des données ou des fichiers sans me le demander.

## Commandes utiles
- Activer l'environnement : .venv\Scripts\activate
- Depuis equancy_dbt : dbt run --select <modèle>, dbt test --select <modèle>, dbt seed

## Prochaines étapes
1. dim_country (à partir du seed) avec tests.
2. Tables de faits (PIB, population, émissions, éducation, démographie) dans leurs fenêtres.
3. Table de couverture, puis un mart par question (a, b, c).
4. Dashboard Power BI (5 pages) et page des hypothèses.