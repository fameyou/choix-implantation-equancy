-- =============================================================================
-- mart_carbon_footprint : réponse à la question c (pays à la plus faible
-- empreinte carbone par habitant et évolution dans le temps).
-- Grain : une ligne par pays souverain et par année, 2010-2021.
-- Les colonnes de niveau pays (moyenne, évolution, rang) sont répétées sur
-- chaque année : le classement se lit en filtrant sur is_latest_year.
-- Hypothèses appliquées :
--   H19 : valeur par habitant fournie par la source (tonnes de CO2 par habitant),
--         classement sur la moyenne 2017-2021 pour lisser 2020 (Covid : -5,9 %).
--   H20 : seuil de population (variable dbt population_min_thousands, 1 million
--         par défaut) appliqué à la dernière population connue sur 2010-2021.
--   H21 : période d'étude 2010-2021. H1 : pays souverains uniquement.
--   H29 : émissions territoriales (production, pas consommation).
-- Règle NULL : un pays sans population connue n'est pas classé (Liban, Andorre).
-- =============================================================================

with

-- Étape 1 : émissions des pays souverains sur la période d'étude.
emissions_sovereign as (
    select
        f.country_code,
        f.year,
        f.co2_tonnes_per_capita,
        f.total_mtco2
    from {{ ref('fct_emissions') }} as f
    inner join {{ ref('dim_country') }} as d
        on d.country_code = f.country_code
    where d.is_ranked_country
      and f.year between 2010 and 2021
      and f.co2_tonnes_per_capita is not null
),

-- Étape 2 : indicateurs de niveau pays (référence de classement et évolution).
country_footprint as (
    select
        country_code,
        avg(co2_tonnes_per_capita) filter (where year between 2017 and 2021)
                                                        as avg_co2_per_capita_2017_2021,
        max(co2_tonnes_per_capita) filter (where year = 2010) as co2_per_capita_2010,
        max(co2_tonnes_per_capita) filter (where year = 2021) as co2_per_capita_2021
    from emissions_sovereign
    group by country_code
),

-- Étape 3 : dernière population connue sur 2010-2021, pour le seuil de taille.
-- Contourne les trous de fct_population (États-Unis 2020-2021, Ukraine après 2013).
latest_population as (
    select distinct on (country_code)
        country_code,
        year                 as reference_population_year,
        population_thousands as reference_population_thousands
    from {{ ref('fct_population') }}
    where year between 2010 and 2021
    order by country_code, year desc
),

-- Étape 4 : évolution 2010-2021 et éligibilité au classement.
country_eligibility as (
    select
        c.country_code,
        c.avg_co2_per_capita_2017_2021,
        c.co2_per_capita_2010,
        c.co2_per_capita_2021,
        round(100 * (c.co2_per_capita_2021 / c.co2_per_capita_2010 - 1), 1)
                                                        as change_2010_2021_pct,
        c.co2_per_capita_2021 - c.co2_per_capita_2010   as change_2010_2021_t,
        p.reference_population_thousands,
        p.reference_population_year,
        coalesce(
            p.reference_population_thousands >= {{ var('population_min_thousands', 1000) }},
            false
        )                                               as is_above_population_threshold
    from country_footprint as c
    left join latest_population as p
        on p.country_code = c.country_code
),

-- Étape 5 : rang parmi les pays éligibles (1 = plus faible empreinte).
-- Le drapeau vaut false sans population connue : le pays n'est pas évaluable,
-- ce n'est pas une valeur imputée.
country_ranking as (
    select
        *,
        is_above_population_threshold                   as is_ranked,
        case
            when is_above_population_threshold then rank() over (
                partition by is_above_population_threshold
                order by avg_co2_per_capita_2017_2021 asc
            )
        end                                             as footprint_rank
    from country_eligibility
)

-- Étape 6 : série annuelle enrichie des indicateurs de niveau pays.
select
    e.country_code,
    e.year,
    e.co2_tonnes_per_capita,
    e.total_mtco2,
    r.avg_co2_per_capita_2017_2021,
    r.co2_per_capita_2010,
    r.co2_per_capita_2021,
    r.change_2010_2021_pct,
    r.change_2010_2021_t,
    r.reference_population_thousands,
    r.reference_population_year,
    r.is_above_population_threshold,
    r.is_ranked,
    r.footprint_rank,
    (e.year = 2021) as is_latest_year
from emissions_sovereign as e
inner join country_ranking as r
    on r.country_code = e.country_code
