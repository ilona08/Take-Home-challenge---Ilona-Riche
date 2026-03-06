with source as (
    select * from {{ ref('orders') }}
)

select
    date_date                    as order_date,
    orders_id                    as order_id,
    customers_id                 as customer_id,
    net_sales
from source