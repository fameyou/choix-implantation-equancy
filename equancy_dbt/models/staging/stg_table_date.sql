select
    to_date(date, 'DD/MM/YYYY') as date_day,
    cast(extract(year from to_date(date, 'DD/MM/YYYY')) as integer) as year
from {{ source('raw', 'table_date') }}