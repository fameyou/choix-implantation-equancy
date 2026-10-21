select
    trim(location) as country_code,
    trim(country) as country_name,
    cast(time as integer) as year,
    cast(replace(value, ',', '.') as numeric) as gdp_value
from {{ source('raw', 'gdp_unesco') }}