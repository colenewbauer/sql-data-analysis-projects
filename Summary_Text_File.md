📦 Olist Brazilian E-Commerce Analytics & Operations Study
📌 Executive Summary
This project analyzes Olist, the largest Brazilian e-commerce marketplace integrator, using SQLite and multi-table relational modeling. The goal of this analysis was to evaluate revenue performance, regional logistics bottlenecks, category-level drivers, customer retention behavior, and seller operational risks.

🛠️ Data Architecture & Pipeline
The relational database (ecommerce.db) integrates raw transaction logs across 5 key tables:

orders: Core order timestamps, delivery estimates, and fulfillment statuses.

payments: Payment methods, installment structures, and transaction amounts.

order_items: Line-item granularity connecting orders, items, prices, and seller IDs.

products: Product dimensions and category taxonomies.

customer: Mapping temporary transaction keys (customer_id) to persistent individual records (customer_unique_id).

💡 Key Analytical Findings
1. Delivery Delays & Regional Logistics Bottlenecks
Top Delayed States: Using global window functions (DENSE_RANK()), the severe delivery delays were concentrated in Rio de Janeiro (RJ), Espírito Santo (ES), and São Paulo (SP).

Operational Reality: SP acts as the central seller fulfillment hub, creating high-volume edge cases, while freight movement into RJ and ES suffers from complex regional transit bottlenecks.

2. Product Category Revenue Drivers
Top Categories: beleza_saude (Health & Beauty), relogios_presentes (Watches & Gifts), and cama_mesa_banho (Bed, Bath & Table).

Commercial Dynamics: Sales are driven by a dual dynamic of high-volume consumables (beleza_saude) and high-AOV premium items (relogios_presentes).

3. Customer Cohort & Repeat Retention Dynamics
Repeat Rate: Monthly cohort analysis reveals an average repeat purchase rate of ~3% to 7%.

Strategic Context: Olist functions primarily as an underlying marketplace integrator rather than a direct-to-consumer destination brand. Customers re-engage with channels like Mercado Livre rather than re-ordering directly through Olist.

4. Seller Concentration & Operational Exposure
Revenue Gap: A ~$100,000 revenue gap exists between the #1 seller and the #10 seller.

AOV vs. Volume: Half of the top 10 revenue sellers generated their revenue off fewer than 1,000 total orders (and 2 with fewer than 500 orders), highlighting heavy reliance on high-ticket sellers.

Delivery Risk: 60% of the top 10 revenue sellers exhibit delivery delay rates exceeding 10% of their total orders.