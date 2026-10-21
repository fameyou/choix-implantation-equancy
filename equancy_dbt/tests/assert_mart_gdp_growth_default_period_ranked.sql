-- =============================================================================
-- Contrôle de volume du classement principal (période par défaut 2010 -> 2021) :
-- au moins 100 pays doivent être classés.
-- Référence observée : 123 pays (124 au-dessus du seuil de 10 Md$, moins le
-- Soudan, exclu pour rupture de série en 2018).
-- Le test échoue (renvoie une ligne) si un filtre a vidé le classement.
-- =============================================================================

with

-- Étape 1 : nombre de pays classés sur la période par défaut
ranked_countries as (
    select
        count(*) as nb_ranked_countries
    from {{ ref('mart_gdp_growth') }}
    where is_default_period
      and is_ranked
)

-- Étape 2 : échec si moins de 100 pays classés
select
    nb_ranked_countries
from ranked_countries
where nb_ranked_countries < 100
