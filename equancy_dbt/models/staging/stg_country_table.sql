select
    trim(country_code) as country_code,
    trim(country) as country_name
from {{ source('raw', 'country_table') }}