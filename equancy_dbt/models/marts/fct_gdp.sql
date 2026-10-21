-- =============================================================================
-- fct_gdp : table de faits du PIB annuel.
-- Grain : une ligne par pays et par année (country_code x year), 2000-2021.
-- Source : stg_gdp_unesco.
-- Unité : dollars US courants (nominaux), cf. H9 et H24.
-- Hypothèses appliquées :
--   H21 : fenêtre de la question a = 2000-2021.
--   H1  : les territoires sont gardés ici ; l'exclusion se fait dans les marts.
--   H25 : les variations annuelles au-delà de x2 ou en deçà de /2 sont signalées
--         (drapeau), jamais supprimées.
-- Règle NULL : une année absente reste absente (pas de ligne créée, pas d'interpolation).
-- =============================================================================

with

-- Étape 1 : lecture du staging, restriction à la fenêtre d'analyse,
-- renommage de la mesure avec son unité.
gdp_in_window as (
    select
        country_code,
        year,
        gdp_value as gdp_usd
    from {{ ref('stg_gdp_unesco') }}
    where year between 2000 and 2021
),

-- Étape 2 : récupération de l'année précédente disponible pour chaque pays.
-- On garde l'année trouvée pour vérifier ensuite qu'elle est bien year - 1
-- (un pays peut avoir des trous dans sa série).
gdp_with_previous_year as (
    select
        country_code,
        year,
        gdp_usd,
        lag(year)    over (partition by country_code order by year) as previous_year,
        lag(gdp_usd) over (partition by country_code order by year) as previous_gdp_usd
    from gdp_in_window
),

-- Étape 3 : croissance annuelle, calculée uniquement si l'année précédente
-- est consécutive. Sinon NULL : on ne fait pas passer une croissance sur
-- plusieurs années pour une croissance annuelle.
gdp_with_growth as (
    select
        country_code,
        year,
        gdp_usd,
        case
            when previous_year = year - 1
            then gdp_usd / nullif(previous_gdp_usd, 0)
        end as gdp_ratio_to_previous_year
    from gdp_with_previous_year
),

-- Étape 4 : mise en forme finale et drapeau de rupture de série (H25).
-- Le drapeau vaut false quand le ratio n'est pas calculable : il signifie
-- « aucune rupture détectée », ce n'est pas une mesure imputée.
final as (
    select
        country_code,
        year,
        gdp_usd,
        round((gdp_ratio_to_previous_year - 1) * 100, 2) as gdp_growth_yoy_pct,
        coalesce(
            gdp_ratio_to_previous_year > 2 or gdp_ratio_to_previous_year < 0.5,
            false
        ) as is_gdp_series_break
    from gdp_with_growth
)

select * from final
