-- =============================================================================
-- fct_emissions : table de faits des émissions de CO2 annuelles.
-- Grain : une ligne par entité et par année (country_code x year), 1950-2021.
-- Source : stg_emissions_per_country.
-- Unités (H9) : MtCO2 pour le total et les sources, tonnes de CO2 par habitant.
-- Hypothèses appliquées :
--   H21 : la table garde 1950-2021 (historique) ; les marts restreignent à 2010-2021.
--   H11 : exclusion des 6 entités historiques sans code ISO et de
--         « St. Kitts-Nevis-Anguilla » (code KNA partagé avec Saint Kitts and Nevis).
--   H1  : territoires et agrégats gardés ici ; exclusion dans les marts.
--   H28 : un zéro de la source signale une absence de mesure (avant
--         l'indépendance, territoire sans population) : il est remis à NULL.
--         1 376 lignes touchées ; aucun pays souverain sur 2010-2021
--         (seuls 4 territoires, dont Porto Rico, à 0 sur toute la période).
-- =============================================================================

with

-- Étape 1 : périmètre de la table (fenêtre et entités joignables).
emissions_in_scope as (
    select
        country_code,
        year,
        total_mtco2,
        coal_mtco2,
        oil_mtco2,
        gas_mtco2,
        cement_mtco2,
        flaring_mtco2,
        other_mtco2,
        co2_per_capita
    from {{ ref('stg_emissions_per_country') }}
    where year between 1950 and 2021
      -- H11 : entités historiques sans code ISO (French West Africa, Ryukyu Islands...)
      and country_code is not null
      -- H11 : entité qui partage le code KNA, elle doublerait les lignes
      and country_name <> 'St. Kitts-Nevis-Anguilla'
),

-- Étape 2 : rétablissement des NULL masqués en zéros (H28).
-- Total nul : aucune mesure cette année-là, toutes les mesures passent à NULL.
-- Total positif : les zéros par source sont de vrais zéros (pays sans charbon).
-- Valeur par habitant nulle : territoire sans population permanente, NULL.
emissions_cleaned as (
    select
        country_code,
        year,
        nullif(total_mtco2, 0)                        as total_mtco2,
        case when total_mtco2 > 0 then coal_mtco2 end    as coal_mtco2,
        case when total_mtco2 > 0 then oil_mtco2 end     as oil_mtco2,
        case when total_mtco2 > 0 then gas_mtco2 end     as gas_mtco2,
        case when total_mtco2 > 0 then cement_mtco2 end  as cement_mtco2,
        case when total_mtco2 > 0 then flaring_mtco2 end as flaring_mtco2,
        case when total_mtco2 > 0 then other_mtco2 end   as other_mtco2,
        nullif(co2_per_capita, 0)                     as co2_tonnes_per_capita
    from emissions_in_scope
)

-- Étape 3 : sélection finale, une ligne par entité et par année.
select
    country_code,
    year,
    total_mtco2,
    coal_mtco2,
    oil_mtco2,
    gas_mtco2,
    cement_mtco2,
    flaring_mtco2,
    other_mtco2,
    co2_tonnes_per_capita
from emissions_cleaned
