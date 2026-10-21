-- =============================================================================
-- mart_co2_education_correlation : question b, coefficients de corrélation.
-- Grain : une ligne par période : la moyenne 2010-2018 (référence) et chacune
--         des années 2010 à 2018 (stabilité du résultat).
-- Coefficients :
--   - Pearson sur valeurs brutes (affiché pour montrer l'effet de l'asymétrie) ;
--   - Pearson sur logarithmes ;
--   - Spearman (corrélation des rangs) : coefficient principal (H17) ;
--   - Spearman partiel au PIB par habitant (H18) :
--       r_xy.z = (r_xy - r_xz * r_yz) / racine((1 - r_xz²) * (1 - r_yz²)).
-- Règle NULL : coefficients calculés sur les pays ayant aussi un PIB par
-- habitant, pour que les quatre coefficients portent sur les mêmes pays.
-- Limite : rank() attribue le rang minimal aux ex-aequo (négligeable sur des
-- valeurs continues).
-- =============================================================================

with

-- Étape 1 : observations par période, sous une forme commune.
-- Moyenne 2010-2018 : une ligne par pays éligible (au moins N années).
average_observations as (
    select
        'Moyenne 2010-2018'                as period_label,
        cast(null as integer)              as year,
        0                                  as period_sort,
        country_code,
        avg_education_usd_per_capita       as education_usd_per_capita,
        avg_co2_tonnes_per_capita          as co2_tonnes_per_capita,
        avg_gdp_usd_per_capita             as gdp_usd_per_capita
    from {{ ref('mart_co2_education') }}
    where is_in_correlation
      and avg_gdp_usd_per_capita is not null
),

-- Années individuelles : une ligne par pays et par année rapprochée.
yearly_observations as (
    select
        'Année ' || cast(year as text)     as period_label,
        year,
        year                               as period_sort,
        country_code,
        education_usd_per_capita,
        co2_tonnes_per_capita,
        gdp_usd_per_capita
    from {{ ref('int_co2_education_paired') }}
    where gdp_usd_per_capita is not null
),

observations as (
    select * from average_observations
    union all
    select * from yearly_observations
),

-- Étape 2 : rangs de chaque variable, calculés à l'intérieur de chaque période.
ranked_observations as (
    select
        *,
        rank() over (partition by period_label order by education_usd_per_capita) as education_rank,
        rank() over (partition by period_label order by co2_tonnes_per_capita)    as co2_rank,
        rank() over (partition by period_label order by gdp_usd_per_capita)       as gdp_rank
    from observations
),

-- Étape 3 : coefficients bruts par période.
coefficients as (
    select
        period_label,
        year,
        period_sort,
        count(*)                                                   as nb_countries,
        corr(education_usd_per_capita, co2_tonnes_per_capita)      as pearson,
        corr(ln(education_usd_per_capita), ln(co2_tonnes_per_capita))
                                                                   as pearson_log,
        corr(education_rank, co2_rank)                             as spearman,
        corr(education_rank, gdp_rank)                             as spearman_education_gdp,
        corr(co2_rank, gdp_rank)                                   as spearman_co2_gdp
    from ranked_observations
    group by period_label, year, period_sort
),

-- Étape 4 : corrélation partielle au PIB par habitant et arrondis d'affichage.
final as (
    select
        period_label,
        year,
        period_sort,
        nb_countries,
        round(cast(pearson as numeric), 3)                 as pearson,
        round(cast(pearson_log as numeric), 3)             as pearson_log,
        round(cast(spearman as numeric), 3)                as spearman,
        round(cast(spearman_education_gdp as numeric), 3)  as spearman_education_gdp,
        round(cast(spearman_co2_gdp as numeric), 3)        as spearman_co2_gdp,
        round(cast(
            (spearman - spearman_education_gdp * spearman_co2_gdp)
            / sqrt((1 - spearman_education_gdp ^ 2) * (1 - spearman_co2_gdp ^ 2))
        as numeric), 3)                                    as spearman_partial_gdp
    from coefficients
)

select * from final
