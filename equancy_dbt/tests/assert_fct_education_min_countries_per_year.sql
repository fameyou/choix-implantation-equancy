-- =============================================================================
-- Contrôle de volume sur la période utile à la question b (2010-2018, H17) :
-- nombre de pays souverains ayant une dépense d'éducation, par année.
-- Le test échoue (renvoie des lignes) si une année compte moins de 100 pays.
-- Référence observée : 106 (2018) à 120 (2017) pays.
-- =============================================================================

with

-- Étape 1 : nombre de pays souverains (H1) par année sur 2010-2018
sovereign_countries_per_year as (
    select
        f.year,
        count(distinct f.country_code) as nb_sovereign_countries
    from {{ ref('fct_education') }} as f
    inner join {{ ref('dim_country') }} as d
        on d.country_code = f.country_code
    where d.is_ranked_country
      and f.year between 2010 and 2018
    group by f.year
)

-- Étape 2 : années sous le seuil (une ligne renvoyée = un échec)
select
    year,
    nb_sovereign_countries
from sovereign_countries_per_year
where nb_sovereign_countries < 100
