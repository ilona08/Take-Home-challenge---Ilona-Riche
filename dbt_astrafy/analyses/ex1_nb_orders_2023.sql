select count(distinct order_id)
from {{ ref('stg_orders') }} # BQ : from `dbt_astrafy.stg_orders`
where extract(year from order_date)=2023