with source as (
    select * from {{ ref('sales') }}
)

select
    date_date       as order_date,
    order_id,
    customer_id,
    products_id     as product_id,
    qty,
    net_sales
from source