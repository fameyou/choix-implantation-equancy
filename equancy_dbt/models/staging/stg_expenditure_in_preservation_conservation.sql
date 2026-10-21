select
    trim(location) as country_code,
    trim(country) as country_name,
    cast(extract(year from to_date(time, 'DD/MM/YYYY')) as integer) as year,
    cast(value as numeric) as heritage_expenditure_ppp_per_capita
from {{ source('raw', 'expenditure_in_preservation_conservation') }}