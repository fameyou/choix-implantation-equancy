-- =============================================================================
-- mart_preselection : synthèse des trois questions et présélection de pays (H22).
-- Grain : une ligne par pays souverain (195), y compris les pays incomplets,
--         pour que le dashboard montre pourquoi un pays n'est pas retenu.
-- Méthode :
--   a : croissance annuelle moyenne du PIB 2010 -> 2021 (mart_gdp_growth) ;
--   b : écart à la tendance éducation ~ CO2 (régression log-log sur les pays
--       de la question b) : ratio > 1 = plus de dépense d'éducation que prévu
--       pour son niveau d'émissions ;
--   c : empreinte carbone par habitant, moyenne 2017-2021 (mart_carbon_footprint).
--   Chaque critère est converti en percentile (0-100) parmi les pays présents
--   sur les trois critères ; score = moyenne des trois percentiles (poids
--   égaux) ; présélection = les preselection_size premiers (5 par défaut).
-- Limite : les données ne mesurent ni le risque politique, ni les
-- infrastructures, ni les coûts ; le score classe, le jugement tranche.
-- =============================================================================

with

-- Étape 1 : univers de la présélection = pays souverains (H1).
sovereign_countries as (
    select country_code
    from {{ ref('dim_country') }}
    where is_ranked_country
),

-- Étape 2 : critère a, croissance sur la période par défaut (pays classés).
growth_criterion as (
    select
        country_code,
        growth_rank,
        cagr_pct
    from {{ ref('mart_gdp_growth') }}
    where is_default_period
      and is_ranked
),

-- Étape 3 : critère c, empreinte carbone (une ligne par pays classé).
footprint_criterion as (
    select
        country_code,
        footprint_rank,
        avg_co2_per_capita_2017_2021
    from {{ ref('mart_carbon_footprint') }}
    where is_latest_year
      and is_ranked
),

-- Étape 4 : critère b, écart à la tendance éducation ~ CO2.
-- 4a : pays de la corrélation, en logarithmes (relation quasi linéaire, H17).
education_base as (
    select
        country_code,
        avg_education_usd_per_capita,
        ln(avg_education_usd_per_capita) as log_education,
        ln(avg_co2_tonnes_per_capita)    as log_co2
    from {{ ref('mart_co2_education') }}
    where is_in_correlation
),

-- 4b : droite de tendance par moindres carrés (log éducation en fonction de log CO2).
education_trend as (
    select
        regr_slope(log_education, log_co2)     as trend_slope,
        regr_intercept(log_education, log_co2) as trend_intercept
    from education_base
),

-- 4c : ratio entre la dépense observée et la dépense prévue par la tendance.
education_criterion as (
    select
        e.country_code,
        e.avg_education_usd_per_capita,
        exp(e.log_education - (t.trend_intercept + t.trend_slope * e.log_co2))
                                         as education_vs_trend_ratio
    from education_base as e
    cross join education_trend as t
),

-- Étape 5 : assemblage des trois critères pour chaque pays souverain.
country_criteria as (
    select
        s.country_code,
        g.growth_rank,
        g.cagr_pct,
        e.avg_education_usd_per_capita,
        e.education_vs_trend_ratio,
        f.footprint_rank,
        f.avg_co2_per_capita_2017_2021,
        (g.country_code is not null
            and e.country_code is not null
            and f.country_code is not null) as is_complete
    from sovereign_countries as s
    left join growth_criterion    as g on g.country_code = s.country_code
    left join education_criterion as e on e.country_code = s.country_code
    left join footprint_criterion as f on f.country_code = s.country_code
),

-- Étape 6 : percentiles (0 = moins bon, 100 = meilleur) parmi les pays complets.
-- Empreinte : ordre décroissant, la plus faible empreinte obtient 100.
criteria_percentiles as (
    select
        country_code,
        100 * percent_rank() over (order by cagr_pct)                          as growth_percentile,
        100 * percent_rank() over (order by education_vs_trend_ratio)          as education_percentile,
        100 * percent_rank() over (order by avg_co2_per_capita_2017_2021 desc) as footprint_percentile
    from country_criteria
    where is_complete
),

-- Étape 7 : score composite (moyenne des trois percentiles, poids égaux).
scored_countries as (
    select
        c.*,
        p.growth_percentile,
        p.education_percentile,
        p.footprint_percentile,
        (p.growth_percentile + p.education_percentile + p.footprint_percentile) / 3
                                                       as composite_score
    from country_criteria as c
    left join criteria_percentiles as p
        on p.country_code = c.country_code
),

-- Étape 8 : rang composite parmi les pays complets.
ranked_countries as (
    select
        *,
        case
            when is_complete then rank() over (
                partition by is_complete
                order by composite_score desc
            )
        end as composite_rank
    from scored_countries
)

-- Étape 9 : sélection finale, présélection et raison d'exclusion.
select
    country_code,
    growth_rank,
    cagr_pct,
    round(avg_education_usd_per_capita, 1)            as avg_education_usd_per_capita,
    round(cast(education_vs_trend_ratio as numeric), 2) as education_vs_trend_ratio,
    footprint_rank,
    round(avg_co2_per_capita_2017_2021, 3)            as avg_co2_per_capita_2017_2021,
    round(cast(growth_percentile as numeric), 1)      as growth_percentile,
    round(cast(education_percentile as numeric), 1)   as education_percentile,
    round(cast(footprint_percentile as numeric), 1)   as footprint_percentile,
    round(cast(composite_score as numeric), 1)        as composite_score,
    composite_rank,
    is_complete,
    coalesce(composite_rank <= {{ var('preselection_size', 5) }}, false)
                                                      as is_preselected,
    nullif(concat_ws(', ',
        case when growth_rank is null              then 'croissance (a)' end,
        case when education_vs_trend_ratio is null then 'éducation (b)' end,
        case when footprint_rank is null           then 'empreinte carbone (c)' end
    ), '')                                            as missing_criteria
from ranked_countries
