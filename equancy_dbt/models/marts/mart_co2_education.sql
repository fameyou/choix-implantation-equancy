-- =============================================================================
-- mart_co2_education : question b, niveau pays (nuage de points du dashboard).
-- Grain : une ligne par pays souverain ayant au moins une observation
--         rapprochée éducation / CO2 sur 2010-2018.
-- Hypothèses appliquées :
--   H17 : moyenne par pays sur 2010-2018 ; un pays entre dans la corrélation
--         s'il a au moins education_min_years années rapprochées (3 par défaut).
--   H18 : PIB par habitant moyen, variable de contrôle.
-- =============================================================================

with

-- Étape 1 : moyennes par pays sur les années rapprochées.
country_averages as (
    select
        country_code,
        count(*)                       as nb_paired_years,
        avg(education_usd_per_capita)  as avg_education_usd_per_capita,
        avg(co2_tonnes_per_capita)     as avg_co2_tonnes_per_capita,
        avg(gdp_usd_per_capita)        as avg_gdp_usd_per_capita
    from {{ ref('int_co2_education_paired') }}
    group by country_code
),

-- Étape 2 : éligibilité à la corrélation (nombre minimal d'années).
final as (
    select
        country_code,
        nb_paired_years,
        round(avg_education_usd_per_capita, 1)  as avg_education_usd_per_capita,
        round(avg_co2_tonnes_per_capita, 3)     as avg_co2_tonnes_per_capita,
        round(avg_gdp_usd_per_capita, 0)        as avg_gdp_usd_per_capita,
        (nb_paired_years >= {{ var('education_min_years', 3) }})
                                                as is_in_correlation
    from country_averages
)

select * from final
