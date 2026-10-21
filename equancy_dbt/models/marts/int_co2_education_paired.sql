{{ config(materialized = 'view') }}

-- =============================================================================
-- int_co2_education_paired : modèle intermédiaire de la question b.
-- Grain : une ligne par pays souverain et par année, 2010-2018, pour laquelle
--         la dépense d'éducation par habitant ET les émissions par habitant
--         sont disponibles (observations rapprochées).
-- Partagé par mart_co2_education et mart_co2_education_correlation : la règle
-- de rapprochement n'est écrite qu'une fois.
-- Hypothèses appliquées :
--   H16 : éducation = dépense publique par habitant (dollars par habitant).
--   H17 : fenêtre 2010-2018 (éducation presque vide ensuite).
--   H18 : PIB par habitant ajouté comme variable de contrôle (nominal, H24).
-- Règle NULL : pas de ligne sans population pour l'année (dépense par habitant
-- non calculable, H30). Le PIB par habitant peut être NULL.
-- =============================================================================

with

-- Étape 1 : dépense d'éducation des pays souverains sur 2010-2018.
education_sovereign as (
    select
        e.country_code,
        e.year,
        e.education_expenditure_musd
    from {{ ref('fct_education') }} as e
    inner join {{ ref('dim_country') }} as d
        on d.country_code = e.country_code
    where d.is_ranked_country
      and e.year between 2010 and 2018
),

-- Étape 2 : rapprochement avec la population et les émissions de la même année.
-- Jointures internes : une observation exige les trois valeurs.
paired_observations as (
    select
        e.country_code,
        e.year,
        e.education_expenditure_musd,
        p.population_thousands,
        c.co2_tonnes_per_capita
    from education_sovereign as e
    inner join {{ ref('fct_population') }} as p
        on  p.country_code = e.country_code
        and p.year         = e.year
    inner join {{ ref('fct_emissions') }} as c
        on  c.country_code = e.country_code
        and c.year         = e.year
    where c.co2_tonnes_per_capita is not null
),

-- Étape 3 : passage aux valeurs par habitant.
-- Dépense : millions de $ x 1 000 000 / (milliers d'habitants x 1 000)
--         = millions de $ x 1 000 / milliers d'habitants.
-- PIB : jointure externe, NULL si le PIB manque (variable de contrôle seulement).
final as (
    select
        o.country_code,
        o.year,
        o.education_expenditure_musd * 1000.0 / o.population_thousands
                                                    as education_usd_per_capita,
        o.co2_tonnes_per_capita,
        g.gdp_usd / (o.population_thousands * 1000.0)
                                                    as gdp_usd_per_capita
    from paired_observations as o
    left join {{ ref('fct_gdp') }} as g
        on  g.country_code = o.country_code
        and g.year         = o.year
)

select * from final
