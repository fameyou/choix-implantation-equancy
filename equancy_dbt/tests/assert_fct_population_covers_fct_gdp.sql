{{ config(severity = 'warn') }}

-- =============================================================================
-- Contrôle de cohérence entre faits : couples pays-année ayant un PIB
-- mais pas de population (pays souverains uniquement).
-- En alerte seulement : ces trous existent dans la source et sont documentés
-- (H26 : 160 couples, dont États-Unis 2020-2021, Japon 2000-2011,
-- Ukraine 2014-2021). Le nombre affiché doit rester stable d'une exécution
-- à l'autre ; une hausse signale une perte de données en amont.
-- Conséquence : le PIB par habitant sera NULL pour ces couples.
-- =============================================================================

with

-- Étape 1 : couples pays-année du PIB, restreints aux pays souverains
sovereign_gdp_rows as (
    select
        g.country_code,
        g.year
    from {{ ref('fct_gdp') }} as g
    inner join {{ ref('dim_country') }} as d
        on d.country_code = g.country_code
    where d.is_ranked_country
)

-- Étape 2 : ceux qui n'ont pas de population (une ligne = un trou)
select
    s.country_code,
    s.year
from sovereign_gdp_rows as s
left join {{ ref('fct_population') }} as p
    on  p.country_code = s.country_code
    and p.year = s.year
where p.country_code is null
