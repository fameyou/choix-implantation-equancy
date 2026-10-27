# Choix d'implantation : test technique Analytics Engineering

Pipeline de données et dashboard Power BI pour aider une entreprise internationale à choisir une zone d'implantation, à partir de 8 fichiers CSV (pays, population, PIB, indicateurs démographiques, émissions de CO2, dépenses d'éducation, dépenses de préservation du patrimoine).

**Résultat : une présélection de 5 pays, avec l'Éthiopie en recommandation principale et le Kenya en alternative.**

| Question | Réponse |
| --- | --- |
| a. Quels pays ont la plus forte croissance du PIB entre deux années ? | Sur 2010 → 2021, l'Éthiopie est n° 1 (+271 %, soit +12,65 % par an), devant le Bangladesh et la Chine. Les deux années sont réglables dans le dashboard. |
| b. Quelle corrélation entre émissions de CO2 et niveau d'éducation ? | Forte (Spearman 0,89 sur 136 pays), mais elle disparaît à PIB par habitant égal (−0,06) : la richesse explique les deux. |
| c. Quels pays ont la plus faible empreinte carbone par habitant, et comment évolue-t-elle ? | La RD Congo (0,028 t par habitant) ; 86 pays sur 156 sont en hausse depuis 2010. |

## Architecture

```
8 fichiers CSV
   │  ingestion Python (pandas, SQLAlchemy) : chargement tel quel, volumes contrôlés
   ▼
PostgreSQL · schéma raw        copie fidèle des CSV, jamais modifiée
   │  dbt Core
   ▼
schéma staging                  une vue par fichier : typage et renommage
   ▼
schéma marts                    modèle en étoile : dim_country, 4 tables de faits,
   │                            un mart par question, présélection, couverture
   ▼
Power BI                        lit les 7 tables marts, aucun calcul métier
```

Tous les nettoyages et calculs (croissance, corrélations de Spearman, classements, score) sont faits dans dbt, versionnés et testés. Power BI ne fait que de l'affichage.

## Contenu du dépôt

| Dossier | Contenu |
| --- | --- |
| `Data/raw/` | Les 8 fichiers CSV d'origine |
| `ingestion/` | Chargement des CSV dans le schéma `raw` (`ingestion.py`) et test de connexion |
| `equancy_dbt/` | Projet dbt : modèles `staging` et `marts`, seed `country_classification`, tests |
| `docs/hypotheses.md` | Les 33 hypothèses (H1 à H33), avec justification et impact |
| `powerbi/` | Le dashboard Power BI et son thème |

## Qualité des données

- **165 tests dbt** : 161 réussis, 4 alertes volontaires (défauts de la source signalés sans bloquer), 0 erreur.
- Tests d'unicité du grain, de valeurs non vides, de relations vers `dim_country`, de valeurs autorisées, de plages plausibles et de règles métier.
- Aucune imputation : une valeur manquante reste vide, et la table `mart_data_coverage` montre quels pays manquent, pour quelle variable.

## Hypothèses principales

Le détail est dans [docs/hypotheses.md](docs/hypotheses.md). Les plus structurantes :

- **H1** : un pays est un État souverain (195) ; territoires et agrégats gardés mais exclus des classements.
- **H4** : jointures sur le code ISO alpha-3, jamais sur le nom.
- **H7** : jamais d'imputation.
- **H16** : l'éducation est approchée par la dépense publique par habitant (un effort, pas un niveau).
- **H21** : période d'étude commune 2010-2021 (2010-2018 pour l'éducation).
- **H22** : score à poids égaux sur les 96 pays présents sur les trois critères ; risque politique et infrastructures non mesurés.
- **H24** : PIB en dollars courants.

## Lancer le projet

Prérequis : Python 3.12, PostgreSQL, Power BI Desktop.

1. **Environnement Python**

   ```
   python -m venv .venv
   .venv\Scripts\activate
   pip install -r requirements.txt
   ```

2. **Connexion à la base** : copier `.env.example` en `.env` et renseigner les identifiants PostgreSQL (base `equancy_test`). Le fichier `.env` n'est jamais versionné.

3. **Chargement des CSV**

   ```
   python ingestion/test_connection.py
   python ingestion/ingestion.py
   ```

4. **dbt** : créer `~/.dbt/profiles.yml` avec un profil `equancy_dbt` pointant vers la même base (adaptateur `postgres`), puis, depuis `equancy_dbt/` :

   ```
   dbt deps
   dbt seed
   dbt run
   dbt test
   dbt docs generate
   dbt docs serve
   ```

   `dbt docs serve` affiche la documentation et le graphe de lignage des modèles.

5. **Power BI** : ouvrir le fichier `.pbix` du dossier `powerbi/`. Les données sont incluses (mode Import) ; pour les actualiser, connecter Power BI à la base `equancy_test`, schéma `marts`.

## Paramètres

Les seuils sont des variables dbt, modifiables sans toucher au SQL : `gdp_min_start_usd` (10 Md$), `population_min_thousands` (1 million d'habitants), `education_min_years` (3 années), `preselection_size` (5 pays).

## Limites

- L'éducation est mesurée par une dépense, pas par un niveau atteint, et le panel est incomplet (53 pays complets sur 195).
- Le PIB est en dollars courants : la croissance inclut l'inflation et les effets de change.
- Les émissions sont le CO2 fossile et ciment, territorial, sans la déforestation.
- Le risque politique, la sécurité, les infrastructures et les coûts ne sont pas dans les données.

---

Komlavi AMEYOU · Master 2 Data Science, Lille · octobre 2026
