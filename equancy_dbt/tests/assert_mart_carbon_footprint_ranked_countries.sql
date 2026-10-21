-- =============================================================================
-- Contrôle de volume du classement de la question c : au moins 140 pays
-- doivent être classés.
-- Référence attendue : 156 pays (population d'au moins 1 million à la
-- dernière année connue ; Liban et Andorre sans population).
-- Le test échoue (renvoie une ligne) si un filtre a vidé le classement.
-- =============================================================================

with

-- Étape 1 : nombre de pays classés (une ligne par pays avec is_latest_year)
ranked_countries as (
    select
        count(*) as nb_ranked_countries
    from {{ ref('mart_carbon_footprint') }}
    where is_latest_year
      and is_ranked
)

-- Étape 2 : échec si moins de 140 pays classés
select
    nb_ranked_countries
from ranked_countries
where nb_ranked_countries < 140
