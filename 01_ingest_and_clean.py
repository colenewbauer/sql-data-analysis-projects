import pandas as pd
import sqlite3

# 1. Load raw CSVs
print("Loading CSV files...")
orders = pd.read_csv("Raw Data/olist_orders_dataset.csv")
payments = pd.read_csv("Raw Data/olist_order_payments_dataset.csv")
customer = pd.read_csv("Raw Data/olist_customers_dataset.csv")
order_items = pd.read_csv("Raw Data/olist_order_items_dataset.csv")
products = pd.read_csv("Raw Data/olist_products_dataset.csv")
product_translation = pd.read_csv("Raw Data/product_category_name_translation.csv")

# 2. Clean timestamps
datetime_cols = [
    'order_purchase_timestamp', 
    'order_delivered_carrier_date', 
    'order_delivered_customer_date', 
    'order_estimated_delivery_date'
]

for col in datetime_cols:
    orders[col] = pd.to_datetime(orders[col])

# 3. Fill missing values
orders['order_status'] = orders['order_status'].fillna('unknown')

# 4. Create SQLite Database connection
conn = sqlite3.connect("ecommerce.db")

# 5. Save tables to SQLite
orders.to_sql("orders", conn, if_exists="replace", index=False)
payments.to_sql("payments", conn, if_exists="replace", index=False)
customer.to_sql("customer", conn, if_exists="replace", index=False)
order_items.to_sql("order_items", conn, if_exists="replace", index=False)
products.to_sql("products", conn, if_exists="replace", index=False)
product_translation.to_sql("product_translation", conn, if_exists="replace", index=False)

print("SUCCESS: Data successfully cleaned and saved to ecommerce.db!")
conn.close()