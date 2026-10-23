-- =============================================================================
-- mart_co2_education : question b, niveau pays (nuage de points du dashboard).
-- Grain : une ligne par pays souverain ayant au moins une observation
--         rapprochée éducation / CO2 sur 2010-2018.
-- Hypothèses appliquées :
--   H17 : moyenne par pays sur 2010-2018 ; un pays entre dans la corrélation
--         s'il a au moins education_min_years années rapprochées (3 par défaut).
--   H18 : PIB par habitant moyen, variable de contrôle.
--   H32 : quartiles de dépense d'éducation, lecture par groupes pour le manager.
--   H33 : quartiles de CO2 par habitant, croisés avec ceux d'éducation (carte de
--         chaleur), pour montrer la relation sans coefficient.
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
country_eligibility as (
    select
        *,
        (nb_paired_years >= {{ var('education_min_years', 3) }}) as is_in_correlation
    from country_averages
),

-- Étape 3 : quartiles parmi les pays de la corrélation, pour la lecture par
-- groupes du dashboard (1 = les 25 % les plus faibles).
--   education_quartile : dépense d'éducation par habitant (H32).
--   co2_quartile       : CO2 par habitant, croisé avec le précédent (H33).
-- NULL pour les pays hors corrélation : ils n'entrent pas dans les groupes.
quartiles as (
    select
        *,
        case
            when is_in_correlation then ntile(4) over (
                partition by is_in_correlation
                order by avg_education_usd_per_capita
            )
        end as education_quartile,
        case
            when is_in_correlation then ntile(4) over (
                partition by is_in_correlation
                order by avg_co2_tonnes_per_capita
            )
        end as co2_quartile
    from country_eligibility
),

-- Étape 4 : arrondis d'affichage et libellés des quartiles.
final as (
    select
        country_code,
        nb_paired_years,
        round(avg_education_usd_per_capita, 1)  as avg_education_usd_per_capita,
        round(avg_co2_tonnes_per_capita, 3)     as avg_co2_tonnes_per_capita,
        round(avg_gdp_usd_per_capita, 0)        as avg_gdp_usd_per_capita,
        is_in_correlation,
        education_quartile,
        case education_quartile
            when 1 then 'Q1 · dépense la plus faible'
            when 2 then 'Q2'
            when 3 then 'Q3'
            when 4 then 'Q4 · dépense la plus élevée'
        end                                     as education_quartile_label,
        co2_quartile,
        case co2_quartile
            when 1 then 'Q1 · CO₂ le plus faible'
            when 2 then 'Q2'
            when 3 then 'Q3'
            when 4 then 'Q4 · CO₂ le plus élevé'
        end                                     as co2_quartile_label
    from quartiles
)

select * from final
