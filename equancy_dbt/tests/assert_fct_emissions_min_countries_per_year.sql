-- =============================================================================
-- Contrôle de volume sur la période d'étude 2010-2021 (H21) : nombre de pays
-- souverains ayant une valeur d'émissions par habitant, par année.
-- Le test échoue (renvoie des lignes) si une année compte moins de 190 pays.
-- Référence observée : 192 pays chaque année (Vatican, Monaco et Saint-Marin
-- sont absents de la source).
-- =============================================================================

with

-- Étape 1 : nombre de pays souverains (H1) avec une valeur par habitant, par année
sovereign_countries_per_year as (
    select
        f.year,
        count(distinct f.country_code) as nb_sovereign_countries
    from {{ ref('fct_emissions') }} as f
    inner join {{ ref('dim_country') }} as d
        on d.country_code = f.country_code
    where d.is_ranked_country
      and f.co2_tonnes_per_capita is not null
      and f.year between 2010 and 2021
    group by f.year
)

-- Étape 2 : années sous le seuil (une ligne renvoyée = un échec)
select
    year,
    nb_sovereign_countries
from sovereign_countries_per_year
where nb_sovereign_countries < 190
