-- =============================================================================
-- dim_country : dimension pays du modèle en étoile.
-- Grain : une ligne par code ISO alpha-3 (241 entités).
-- Source : seed country_classification (195 pays souverains, 44 territoires,
--          2 agrégats), construit à partir de tous les codes présents dans
--          les fichiers sources (hypothèse H5), et non à partir de Country_Table.
-- Hypothèses appliquées :
--   H1 : seul un État souverain (entity_type = 'country') entre dans les classements.
--   H4 : toutes les jointures avec les faits se font sur country_code, jamais sur le nom.
-- =============================================================================

with

-- Étape 1 : lecture du seed avec une normalisation défensive.
-- Le seed est propre aujourd'hui, mais un espace ou une minuscule ajoutés lors
-- d'une future modification du CSV casseraient les jointures sans erreur visible.
source_classification as (
    select
        upper(trim(country_code)) as country_code,
        trim(country_name)        as country_name,
        lower(trim(entity_type))  as entity_type
    from {{ ref('country_classification') }}
),

-- Étape 2 : attributs dérivés destinés à l'analyse et au dashboard.
-- is_ranked_country : drapeau unique utilisé par les trois marts (a, b, c)
--   pour exclure les territoires et les agrégats des classements (H1).
-- entity_type_label : libellé en français pour les filtres Power BI.
country_enriched as (
    select
        country_code,
        country_name,
        entity_type,
        case entity_type
            when 'country'   then 'Pays souverain'
            when 'territory' then 'Territoire'
            when 'aggregate' then 'Agrégat'
        end                         as entity_type_label,
        (entity_type = 'country')   as is_ranked_country
    from source_classification
)

-- Étape 3 : sélection finale, une ligne par entité.
select
    country_code,
    country_name,
    entity_type,
    entity_type_label,
    is_ranked_country
from country_enriched
