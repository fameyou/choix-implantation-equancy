select
    trim(location) as country_code,
    trim(country) as country_name,
    trim(indicator) as indicator_name,
    case trim(indicator)
        when 'Life expectancy at birth, total (years)' then 'life_expectancy'
        when 'Rural population (% of total population)' then 'rural_population_pct'
        else null
    end as indicator_code,
    cast(extract(year from to_date(time, 'DD/MM/YYYY')) as integer) as year,
    cast(value as numeric) as indicator_value
from {{ source('raw', 'demographic_indicators') }}