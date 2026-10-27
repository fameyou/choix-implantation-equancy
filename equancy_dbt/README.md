# equancy_dbt

Projet dbt du test technique « Choix d'implantation ». Vue d'ensemble, installation et hypothèses : voir le [README du dépôt](../README.md).

## Couches

| Schéma | Matérialisation | Rôle |
| --- | --- | --- |
| `staging` | vues | une vue par fichier source : typage et renommage, aucune règle métier |
| `marts` | tables | `dim_country`, tables de faits (`fct_gdp`, `fct_population`, `fct_emissions`, `fct_education`) et marts d'analyse |

## Marts d'analyse

| Modèle | Rôle |
| --- | --- |
| `mart_gdp_growth` | question a : croissance du PIB pour les 66 couples d'années de 2010 à 2021 |
| `mart_co2_education` | question b : moyennes par pays 2010-2018, quartiles d'éducation et de CO2 |
| `mart_co2_education_correlation` | question b : Pearson, Spearman et Spearman partiel au PIB, par période |
| `mart_carbon_footprint` | question c : empreinte carbone par habitant 2010-2021 et classement |
| `mart_preselection` | synthèse des trois questions, score composite et présélection |
| `mart_data_coverage` | couverture des données par pays et par variable |

## Commandes

```
dbt deps
dbt seed
dbt run
dbt test
dbt docs generate
dbt docs serve
```
