select
    trim(location) as country_code,
    trim(country) as country_name,
    cast(extract(year from to_date(time, 'DD/MM/YYYY')) as integer) as year,
    cast(value as bigint) as population_thousands
from {{ source('raw', 'population_thousands') }}