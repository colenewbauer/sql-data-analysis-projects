-- =============================================================================
-- Query 1: Revenue & Average Delivery Delays by Order Status
-- Purpose: Quantify total revenue by order status and establish baseline 
--          delivery delay metrics for fulfilled orders.
-- =============================================================================
WITH order_revenue AS (
    SELECT 
        o.order_id,
        o.order_status,
        p.payment_value,
        -- Convert timestamps to Julian days to allow decimal subtraction for exact delay durations
        JULIANDAY(o.order_delivered_customer_date) - JULIANDAY(o.order_estimated_delivery_date) AS delay_days
    FROM orders o
    -- Join pre-aggregated payment totals to prevent row multiplication (double fan-out)
    LEFT JOIN (
        SELECT order_id, SUM(payment_value) AS payment_value
        FROM payments
        GROUP BY order_id
    ) p ON o.order_id = p.order_id
)
SELECT 
    order_status,
    COUNT(order_id) AS total_orders,
    ROUND(SUM(payment_value), 2) AS total_revenue,
    -- Conditional aggregation: Only average positive delays to isolate late shipments
    ROUND(AVG(CASE WHEN delay_days > 0 THEN delay_days ELSE 0 END), 1) AS avg_delay_days
FROM order_revenue
GROUP BY order_status
ORDER BY total_revenue DESC;


-- =============================================================================
-- Query 2: Severe Delivery Delays Across Network (Global Ranking)
-- Purpose: Identify extreme delivery delays and geographic concentration 
--          without partitioning, using window functions.
-- =============================================================================
WITH order_delays AS (
    SELECT 
        o.order_id,
        c.customer_state,
        -- Measure delay in decimal days, rounded to 1 decimal place
        ROUND(JULIANDAY(o.order_delivered_customer_date) - JULIANDAY(o.order_estimated_delivery_date), 1) AS delay_days,
        -- Window Function: Global ranking across the entire table (no PARTITION BY)
        -- Ties receive the same rank, and no rank numbers are skipped
        DENSE_RANK() OVER (
            ORDER BY (JULIANDAY(o.order_delivered_customer_date) - JULIANDAY(o.order_estimated_delivery_date)) DESC
        ) AS delay_rank
    FROM orders o
    LEFT JOIN customer c ON o.customer_id = c.customer_id
    -- Filter out on-time or early deliveries prior to ranking
    WHERE o.order_delivered_customer_date > o.order_estimated_delivery_date
)
SELECT 
    customer_state,
    order_id,
    delay_days,
    delay_rank
FROM order_delays
-- Filter on the window function output (must happen outside the CTE where delay_rank was created)
WHERE delay_rank <= 3
ORDER BY delay_days DESC;


-- =============================================================================
-- Query 3: Top Revenue Product Categories & Freight Performance
-- Purpose: Find top revenue-driving product categories while evaluating 
--          shipping friction (freight cost & delays).
-- =============================================================================
SELECT 
    pt.product_category_name_english,
    COUNT(DISTINCT o.order_id) AS total_orders,
    -- Sum item prices directly from order_items (omitting payments table avoids double fan-out)
    ROUND(SUM(oi.price), 2) AS total_item_revenue,
    ROUND(AVG(oi.freight_value), 2) AS avg_freight,
    -- Calculate average delay strictly for late deliveries within each category
    ROUND(AVG(
        CASE 
            WHEN JULIANDAY(o.order_delivered_customer_date) > JULIANDAY(o.order_estimated_delivery_date) 
            THEN JULIANDAY(o.order_delivered_customer_date) - JULIANDAY(o.order_estimated_delivery_date) 
            ELSE 0 
        END
    ), 1) AS avg_delay_days
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN products prod ON oi.product_id = prod.product_id
LEFT JOIN product_translation pt on prod.product_category_name = pt.product_category_name
WHERE o.order_status = 'delivered'
  AND pt.product_category_name_english IS NOT NULL
GROUP BY pt.product_category_name_english
ORDER BY total_item_revenue DESC
LIMIT 10;


-- =============================================================================
-- Query 4: Customer Cohort Analysis & Retention Dynamics
-- Purpose: Group customers by the month of their first purchase to measure
--          repeat order behavior over time.
-- =============================================================================
WITH customer_activity AS (
    SELECT 
        -- Must join to 'customer' table to use 'customer_unique_id' (persistent human ID)
        -- rather than 'customer_id' (single-transaction token)
        c.customer_unique_id,
        -- Extract Year-Month of the customer's very first purchase date
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
    -- Conditional SUM: Count 1 for users with >1 lifetime order, 0 otherwise
    SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    -- Calculate repeat rate percentage
    -- Note: '1.0 *' forces float division in SQLite to avoid integer division returning 0
    ROUND(
        (SUM(CASE WHEN total_orders > 1 THEN 1.0 ELSE 0 END) / COUNT(customer_unique_id)) * 100, 
        2
    ) AS repeat_rate_pct
FROM customer_activity
GROUP BY cohort_month
ORDER BY cohort_month ASC;


-- =============================================================================
-- Query 5: Seller Revenue Concentration & Delay Risk Deep Dive
-- Purpose: Evaluate revenue concentration per seller and identify operational 
--          vulnerabilities (sellers with high revenue but high delay rates).
-- =============================================================================
SELECT 
    oi.seller_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    -- Average delay in days across all late shipments for this seller
    ROUND(
        AVG(
            CASE 
                WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date 
                THEN JULIANDAY(o.order_delivered_customer_date) - JULIANDAY(o.order_estimated_delivery_date) 
                ELSE 0 
            END
        ), 1
    ) AS avg_delay_days,
    -- Count of total orders delivered past the estimated date
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
ORDER BY total_revenue DESC;
