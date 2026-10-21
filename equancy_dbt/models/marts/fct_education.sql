-- =============================================================================
-- fct_education : table de faits des dépenses publiques d'éducation.
-- Grain : une ligne par pays et par année avec une dépense observée,
--         2010-2021 (country_code x year).
-- Source : stg_government_expenses_in_education.
-- Unité : millions de dollars US (ordre de grandeur vérifié : 4 à 6 % du PIB).
-- Hypothèses appliquées :
--   H16 : la dépense publique d'éducation sert d'approximation du niveau
--         d'éducation (mesure un effort, pas un résultat).
--   H21 : la table garde 2010-2021 ; le mart de la question b restreint à
--         2010-2018 (H17), l'éducation étant presque vide ensuite.
--   H30 : panel incomplet (35 pays souverains sans aucune donnée, dont Chine,
--         Nigeria, Égypte) ; lignes sans valeur exclues (Vatican, 13 lignes).
--   H1  : territoires gardés ici ; exclusion dans les marts.
-- Règle NULL : une année absente reste absente. La valeur par habitant n'est
-- pas calculée ici mais dans le mart b (jointure avec fct_population).
-- =============================================================================

with

-- Étape 1 : lecture du staging, restriction à la fenêtre d'analyse.
education_in_window as (
    select
        country_code,
        year,
        education_expenditure_musd
    from {{ ref('stg_government_expenses_in_education') }}
    where year between 2010 and 2021
),

-- Étape 2 : conservation des seules observations.
-- Les lignes sans valeur (Vatican, toutes les années) ne portent aucune
-- information ; leur absence sera visible dans la table de couverture.
education_observed as (
    select
        country_code,
        year,
        education_expenditure_musd
    from education_in_window
    where education_expenditure_musd is not null
)

-- Étape 3 : sélection finale, une ligne par pays et par année observée.
select
    country_code,
    year,
    education_expenditure_musd
from education_observed
