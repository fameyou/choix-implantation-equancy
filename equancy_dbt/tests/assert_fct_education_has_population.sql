{{ config(severity = 'warn') }}

-- =============================================================================
-- Contrôle de cohérence entre faits : couples pays-année ayant une dépense
-- d'éducation mais pas de population (pays souverains uniquement).
-- En alerte seulement : ces trous viennent de la source (H26) et sont
-- documentés (37 couples : Japon 2010-2011, Ukraine 2014-2018, Andorre,
-- Monaco, Singapour, Liban, Moldavie, Brésil 2010...).
-- Conséquence : la dépense d'éducation par habitant (question b) sera NULL
-- pour ces couples. Une hausse du nombre signale une perte de données.
-- =============================================================================

with

-- Étape 1 : couples pays-année de l'éducation, restreints aux pays souverains
sovereign_education_rows as (
    select
        e.country_code,
        e.year
    from {{ ref('fct_education') }} as e
    inner join {{ ref('dim_country') }} as d
        on d.country_code = e.country_code
    where d.is_ranked_country
)

-- Étape 2 : ceux qui n'ont pas de population (une ligne = un trou)
select
    s.country_code,
    s.year
from sovereign_education_rows as s
left join {{ ref('fct_population') }} as p
    on  p.country_code = s.country_code
    and p.year = s.year
where p.country_code is null
