-- =============================================================================
-- mart_data_coverage : table de couverture des données (H23).
-- Grain : une ligne par entité et par variable (241 x 4 = 964 lignes).
-- Objectif : rendre visible, dans le dashboard, quels pays manquent pour
-- quelle variable et quelles années, afin qu'aucune donnée ne disparaisse
-- en silence d'un classement.
-- Périodes de référence (H21, H17) : PIB, population et CO2 par habitant sur
-- 2010-2021 ; dépense d'éducation sur 2010-2018, période utile à la question b.
-- Une observation = une valeur non NULL dans la table de faits (pour les
-- émissions : la valeur par habitant, mesure de la question c).
-- =============================================================================

with

-- Étape 1 : référentiel des variables suivies, de leur période de référence
-- et de leur ordre d'affichage dans le dashboard (variable_sort).
variables as (
    select *
    from (
        values
            ('co2_per_capita', 'Émissions de CO2 par habitant',  2010, 2021, 1),
            ('gdp',            'PIB',                            2010, 2021, 2),
            ('population',     'Population',                     2010, 2021, 3),
            ('education',      'Dépense publique d''éducation',  2010, 2018, 4)
    ) as v (variable_code, variable_label, reference_start_year, reference_end_year, variable_sort)
),

-- Étape 2 : années attendues pour chaque variable (une ligne par année).
expected_years as (
    select
        v.variable_code,
        cast(y.year as integer) as year
    from variables as v
    cross join lateral generate_series(
        v.reference_start_year, v.reference_end_year
    ) as y (year)
),

-- Étape 3 : grille complète attendue entité x variable x année.
expected_grid as (
    select
        d.country_code,
        e.variable_code,
        e.year
    from {{ ref('dim_country') }} as d
    cross join expected_years as e
),

-- Étape 4 : observations réelles, une ligne par entité, variable et année.
observations as (
    select country_code, 'gdp' as variable_code, year
    from {{ ref('fct_gdp') }}

    union all

    select country_code, 'population' as variable_code, year
    from {{ ref('fct_population') }}

    union all

    select country_code, 'co2_per_capita' as variable_code, year
    from {{ ref('fct_emissions') }}
    where co2_tonnes_per_capita is not null

    union all

    select country_code, 'education' as variable_code, year
    from {{ ref('fct_education') }}
),

-- Étape 5 : rapprochement attendu / observé, année par année.
grid_with_observation as (
    select
        g.country_code,
        g.variable_code,
        g.year,
        (o.country_code is not null) as is_observed
    from expected_grid as g
    left join observations as o
        on  o.country_code  = g.country_code
        and o.variable_code = g.variable_code
        and o.year          = g.year
),

-- Étape 6 : agrégation par entité et par variable.
coverage_by_country_variable as (
    select
        country_code,
        variable_code,
        count(*)                                       as nb_years_expected,
        count(*) filter (where is_observed)            as nb_years_observed,
        min(year) filter (where is_observed)           as first_year_observed,
        max(year) filter (where is_observed)           as last_year_observed,
        string_agg(cast(year as text), ', ' order by year)
            filter (where not is_observed)             as missing_years
    from grid_with_observation
    group by country_code, variable_code
),

-- Étape 7 : indicateurs d'affichage (taux, statut et ordres de tri).
-- Les ordres de tri sont fournis par le mart : Power BI ne peut pas trier une
-- colonne par une colonne calculée qui dépend d'elle (dépendance circulaire).
final as (
    select
        c.country_code,
        c.variable_code,
        v.variable_label,
        v.variable_sort,
        v.reference_start_year,
        v.reference_end_year,
        c.nb_years_expected,
        c.nb_years_observed,
        round(100.0 * c.nb_years_observed / c.nb_years_expected, 1) as completeness_pct,
        c.first_year_observed,
        c.last_year_observed,
        c.missing_years,
        case
            when c.nb_years_observed = c.nb_years_expected then 'Complète'
            when c.nb_years_observed = 0                   then 'Absente'
            else 'Partielle'
        end as coverage_status,
        -- Ordre de lecture : Complète (1), Partielle (2), Absente (3)
        case
            when c.nb_years_observed = c.nb_years_expected then 1
            when c.nb_years_observed = 0                   then 3
            else 2
        end as coverage_status_sort
    from coverage_by_country_variable as c
    inner join variables as v
        on v.variable_code = c.variable_code
)

select * from final
