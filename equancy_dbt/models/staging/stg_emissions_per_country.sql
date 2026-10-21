select
    trim(country) as country_name,
    trim(iso_3166_1_alpha_3) as country_code,
    cast(year as integer) as year,
    cast(total as numeric) as total_mtco2,
    cast(coal as numeric) as coal_mtco2,
    cast(oil as numeric) as oil_mtco2,
    cast(gas as numeric) as gas_mtco2,
    cast(cement as numeric) as cement_mtco2,
    cast(flaring as numeric) as flaring_mtco2,
    cast(other as numeric) as other_mtco2,
    cast(per_capita as numeric) as co2_per_capita
from {{ source('raw', 'emissions_per_country') }}