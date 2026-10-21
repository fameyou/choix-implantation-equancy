-- =============================================================================
-- Contrôle de volume : nombre de pays souverains ayant une population, par année.
-- Le test échoue (renvoie des lignes) si une année compte moins de 175 pays.
-- Référence observée : 186 à 192 pays de 2000 à 2020, 178 en 2021 (minimum).
-- =============================================================================

with

-- Étape 1 : nombre de pays souverains (H1) par année dans la table de faits
sovereign_countries_per_year as (
    select
        f.year,
        count(distinct f.country_code) as nb_sovereign_countries
    from {{ ref('fct_population') }} as f
    inner join {{ ref('dim_country') }} as d
        on d.country_code = f.country_code
    where d.is_ranked_country
    group by f.year
)

-- Étape 2 : années sous le seuil (une ligne renvoyée = un échec)
select
    year,
    nb_sovereign_countries
from sovereign_countries_per_year
where nb_sovereign_countries < 175
