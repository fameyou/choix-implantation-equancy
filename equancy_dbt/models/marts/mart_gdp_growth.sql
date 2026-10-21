-- =============================================================================
-- mart_gdp_growth : réponse à la question a (croissance du PIB entre deux années).
-- Grain : une ligne par pays souverain et par couple (année de départ, année
--         d'arrivée), 2010-2021, départ < arrivée (66 couples possibles).
-- Hypothèses appliquées :
--   H14 : croissance = variation en % entre deux années choisies dans le
--         dashboard ; tous les couples sont précalculés, défaut 2010 -> 2021.
--   H15 : seuil de taille sur le PIB de l'année de départ (variable dbt
--         gdp_min_start_usd, 10 Md$ par défaut) pour écarter les micro-économies.
--   H25 : un pays avec une rupture de série dans la période reste dans la table
--         mais n'est pas classé.
--   H21 : période d'étude 2010-2021. H1 : pays souverains uniquement.
--   H24 : croissance nominale en dollars courants.
-- Règle NULL : un couple n'existe que si le PIB est présent aux deux dates.
-- =============================================================================

with

-- Étape 1 : PIB des pays souverains sur la période d'étude.
gdp_sovereign as (
    select
        f.country_code,
        f.year,
        f.gdp_usd,
        f.is_gdp_series_break
    from {{ ref('fct_gdp') }} as f
    inner join {{ ref('dim_country') }} as d
        on d.country_code = f.country_code
    where d.is_ranked_country
      and f.year between 2010 and 2021
),

-- Étape 2 : tous les couples (départ, arrivée) disponibles pour chaque pays.
-- L'auto-jointure ne crée un couple que si les deux années ont un PIB.
year_pairs as (
    select
        s.country_code,
        s.year     as start_year,
        e.year     as end_year,
        s.gdp_usd  as gdp_start_usd,
        e.gdp_usd  as gdp_end_usd
    from gdp_sovereign as s
    inner join gdp_sovereign as e
        on  e.country_code = s.country_code
        and e.year > s.year
),

-- Étape 3 : rupture de série dans la période (H25).
-- Une rupture datée de l'année Y porte sur le passage Y-1 -> Y : elle est dans
-- la période si start_year < Y <= end_year.
series_breaks_in_period as (
    select
        p.country_code,
        p.start_year,
        p.end_year,
        bool_or(g.is_gdp_series_break) as has_series_break_in_period
    from year_pairs as p
    inner join gdp_sovereign as g
        on  g.country_code = p.country_code
        and g.year >  p.start_year
        and g.year <= p.end_year
    group by p.country_code, p.start_year, p.end_year
),

-- Étape 4 : indicateurs de croissance et règles d'éligibilité au classement.
growth_metrics as (
    select
        p.country_code,
        p.start_year,
        p.end_year,
        p.end_year - p.start_year                                    as nb_years,
        p.gdp_start_usd,
        p.gdp_end_usd,
        round(100 * (p.gdp_end_usd / p.gdp_start_usd - 1), 2)        as growth_pct,
        round(100 * (power(p.gdp_end_usd / p.gdp_start_usd,
                           1.0 / (p.end_year - p.start_year)) - 1), 2) as cagr_pct,
        (p.gdp_start_usd >= {{ var('gdp_min_start_usd', 10000000000) }})
                                                                     as is_above_size_threshold,
        b.has_series_break_in_period
    from year_pairs as p
    inner join series_breaks_in_period as b
        on  b.country_code = p.country_code
        and b.start_year   = p.start_year
        and b.end_year     = p.end_year
),

-- Étape 5 : éligibilité au classement (seuil atteint et aucune rupture).
growth_eligibility as (
    select
        *,
        (is_above_size_threshold and not has_series_break_in_period) as is_ranked
    from growth_metrics
),

-- Étape 6 : rang parmi les pays éligibles, pour chaque couple d'années.
-- rank() : deux pays à égalité partagent le même rang.
final as (
    select
        country_code,
        start_year,
        end_year,
        nb_years,
        gdp_start_usd,
        gdp_end_usd,
        growth_pct,
        cagr_pct,
        is_above_size_threshold,
        has_series_break_in_period,
        is_ranked,
        case
            when is_ranked then rank() over (
                partition by start_year, end_year, is_ranked
                order by growth_pct desc
            )
        end                                          as growth_rank,
        (start_year = 2010 and end_year = 2021)      as is_default_period
    from growth_eligibility
)

select * from final
