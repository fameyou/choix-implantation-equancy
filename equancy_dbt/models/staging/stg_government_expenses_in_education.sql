select
    trim(location) as country_code,
    trim(country) as country_name,
    cast(extract(year from to_date(time, 'DD/MM/YYYY')) as integer) as year,
    cast(value as numeric) as education_expenditure_musd
from {{ source('raw', 'government_expenses_in_education') }}