-- =============================================================================
-- fct_population : table de faits de la population annuelle.
-- Grain : une ligne par pays et par année (country_code x year), 2000-2021.
-- Source : stg_population_thousands.
-- Unité : milliers d'habitants, entiers (H27 : précision faible pour les micro-États).
-- Hypothèses appliquées :
--   H26 : fenêtre 2000-2021, alignée sur le PIB et les émissions ; l'année 2022
--         reste en staging car aucune autre table de faits ne la couvre.
--   H1  : les territoires sont gardés ici ; l'exclusion se fait dans les marts.
-- Règle NULL : une année absente reste absente (ex. États-Unis 2020-2021,
-- Japon avant 2012, Ukraine après 2013). Pas d'interpolation, pas de ligne créée.
-- =============================================================================

with

-- Étape 1 : lecture du staging et restriction à la fenêtre d'analyse.
population_in_window as (
    select
        country_code,
        year,
        population_thousands
    from {{ ref('stg_population_thousands') }}
    where year between 2000 and 2021
)

-- Étape 2 : sélection finale, une ligne par pays et par année.
select
    country_code,
    year,
    population_thousands
from population_in_window
