import sqlite3
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

# Set a cohesive visual style for charts
sns.set_theme(style="whitegrid")
plt.rcParams.update({"font.size": 11})

# Connect to your SQLite database
conn = sqlite3.connect("ecommerce.db")

# -----------------------------------------------------------------------------
# CHART 1: Top 10 Product Categories by Revenue
# -----------------------------------------------------------------------------
query_categories = """
SELECT 
    pt.product_category_name_english,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_item_revenue,
    ROUND(AVG(oi.freight_value), 2) AS avg_freight
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN products prod ON oi.product_id = prod.product_id
LEFT JOIN product_translation pt on prod.product_category_name = pt.product_category_name
WHERE o.order_status = 'delivered'
  AND pt.product_category_name_english IS NOT NULL
GROUP BY pt.product_category_name_english
ORDER BY total_item_revenue DESC
LIMIT 10;
"""

df_categories = pd.read_sql_query(query_categories, conn)

plt.figure(figsize=(12, 6))
barplot = sns.barplot(
    data=df_categories,
    x="total_item_revenue",
    y="product_category_name_english",
    palette="Blues_r"
)

# Format x-axis labels as currency
plt.title("Top 10 Product Categories by Revenue (BRL)", fontsize=14, fontweight="bold", pad=15)
plt.xlabel("Total Item Revenue (R$)", fontsize=12)
plt.ylabel("Product Category", fontsize=12)

# Annotate exact values on the bars
for p in barplot.patches:
    width = p.get_width()
    plt.text(
        width + 15000, 
        p.get_y() + p.get_height() / 2, 
        f"R$ {width:,.0f}", 
        va="center", 
        fontsize=10
    )

plt.tight_layout()
plt.savefig("top_categories_revenue.png", dpi=300)
plt.show()

# -----------------------------------------------------------------------------
# CHART 2: Top 10 Sellers Revenue vs. Delay Percentage
# -----------------------------------------------------------------------------
query_sellers = """
SELECT 
    oi.seller_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    SUM(
        CASE 
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date 
            THEN 1 
            ELSE 0 
        END
    ) AS delayed_orders_count
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
  AND oi.seller_id IS NOT NULL
GROUP BY oi.seller_id
ORDER BY total_revenue DESC
LIMIT 10;
"""

df_sellers = pd.read_sql_query(query_sellers, conn)

# Calculate the delay rate percentage per seller
df_sellers["delay_rate_pct"] = (df_sellers["delayed_orders_count"] / df_sellers["total_orders"]) * 100

# Truncate seller IDs for cleaner plot labels
df_sellers["seller_label"] = df_sellers["seller_id"].str[:8] + "..."

plt.figure(figsize=(12, 6))
bar_seller = sns.barplot(
    data=df_sellers,
    x="seller_label",
    y="delay_rate_pct",
    palette="Reds_r"
)

# Highlight the 10% benchmark threshold
plt.axhline(10, color="black", linestyle="--", linewidth=1.5, label="10% Delay Benchmark")

plt.title("Top 10 Revenue Sellers: Delivery Delay Rate (%)", fontsize=14, fontweight="bold", pad=15)
plt.xlabel("Seller ID (Shortened)", fontsize=12)
plt.ylabel("Delayed Orders (%)", fontsize=12)
plt.xticks(rotation=45)
plt.legend(loc="upper right")

# Annotate exact percentage values on bars
for p in bar_seller.patches:
    height = p.get_height()
    if height > 0:
        plt.text(
            p.get_x() + p.get_width() / 2, 
            height + 0.5, 
            f"{height:.1f}%", 
            ha="center", 
            fontsize=10
        )

plt.tight_layout()
plt.savefig("top_sellers_delay_rate.png", dpi=300)
plt.show()

# -----------------------------------------------------------------------------
# CHART 3: Monthly Customer Acquisition & Repeat Purchase Rate
# -----------------------------------------------------------------------------
query_cohorts = """
WITH customer_activity AS (
    SELECT 
        c.customer_unique_id,
        STRFTIME('%Y-%m', MIN(o.order_purchase_timestamp)) AS cohort_month, 
        COUNT(DISTINCT o.order_id) AS total_orders
    FROM orders o
    LEFT JOIN customer c ON o.customer_id = c.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT 
    cohort_month,
    COUNT(customer_unique_id) AS total_new_customers, 
    SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(
        (SUM(CASE WHEN total_orders > 1 THEN 1.0 ELSE 0 END) / COUNT(customer_unique_id)) * 100, 
        2
    ) AS repeat_rate_pct
FROM customer_activity
GROUP BY cohort_month
HAVING cohort_month >= '2017-01' AND cohort_month <= '2018-08'
ORDER BY cohort_month ASC;
"""

df_cohorts = pd.read_sql_query(query_cohorts, conn)

# Create a dual-axis plot: Bar chart for New Customers, Line chart for Repeat Rate (%)
fig, ax1 = plt.subplots(figsize=(14, 6))

# Bar plot on primary y-axis (Customer Acquisition Volume)
sns.barplot(
    data=df_cohorts, 
    x="cohort_month", 
    y="total_new_customers", 
    color="#4C72B0", 
    alpha=0.6, 
    ax=ax1
)
ax1.set_ylabel("Total New Customers Joined", fontsize=12, color="#4C72B0", fontweight="bold")
ax1.set_xlabel("Cohort Month (First Purchase)", fontsize=12)
ax1.tick_params(axis="x", rotation=45)

# Secondary y-axis for Repeat Rate (%)
ax2 = ax1.twinx()
sns.lineplot(
    data=df_cohorts, 
    x="cohort_month", 
    y="repeat_rate_pct", 
    color="#C44E52", 
    marker="o", 
    linewidth=2.5, 
    ax=ax2
)
ax2.set_ylabel("Repeat Rate (%)", fontsize=12, color="#C44E52", fontweight="bold")
ax2.grid(False)  # Turn off secondary grid lines to keep chart crisp

# Benchmark reference line for 5% average repeat rate
ax2.axhline(5.0, color="gray", linestyle="--", alpha=0.7, label="~5% Network Average")

plt.title("Olist Customer Acquisition Volume vs. Repeat Retention Rate (%)", fontsize=14, fontweight="bold", pad=15)
fig.tight_layout()
plt.savefig("cohort_acquisition_retention.png", dpi=300)
plt.show()

# Close database connection
conn.close()