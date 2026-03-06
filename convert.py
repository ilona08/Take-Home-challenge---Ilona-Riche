import pandas as pd

df_orders = pd.read_excel("data/orders_recrutement.xlsx")
df_orders.to_csv("dbt_astrafy/seeds/orders.csv", index=False)
print("orders.csv généré ✓")

df_sales = pd.read_excel("data/sales_recrutement.xlsx")
df_sales.to_csv("dbt_astrafy/seeds/sales.csv", index=False)
print("sales.csv généré ✓")