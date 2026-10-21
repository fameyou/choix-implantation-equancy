-- =============================================================================
-- Contrôle d'exhaustivité (H23) : chaque entité de dim_country doit avoir
-- exactement 4 lignes dans la table de couverture, une par variable.
-- Le test échoue (renvoie des lignes) pour toute entité absente ou incomplète.
-- =============================================================================

with

-- Étape 1 : nombre de variables par entité dans la table de couverture
variables_per_country as (
    select
        d.country_code,
        count(c.variable_code) as nb_variables
    from {{ ref('dim_country') }} as d
    left join {{ ref('mart_data_coverage') }} as c
        on c.country_code = d.country_code
    group by d.country_code
)

-- Étape 2 : entités qui n'ont pas exactement 4 variables
select
    country_code,
    nb_variables
from variables_per_country
where nb_variables <> 4
