/* ============================================================================
   PROJECT: Food Waste App - Merchant & Surplus Order Data Pipeline
   AUTHOR: Cole Newbauer
   DATE: July 2026
   FOCUS: Data Lifecycle Stage 3 — Data Cleaning & Standardization
   
   BUSINESS CONTEXT:
   The Operations Team at a surplus food marketplace (e.g., Too Good To Go) 
   needs a clean, standardized dataset to analyze 2026 performance across 
   merchant categories, order volume tiers, and cancellation trends.
============================================================================ */

SELECT 
    merch.merchant_id,
    merch.merchant_name,
    
    -- 1. CATEGORY STANDARDIZATION
    -- Trims leading/trailing whitespace from messy user inputs and converts
    -- all category strings to uppercase for uniform grouping downstream.
    UPPER(TRIM(merch.category)) AS clean_category,
    
    so.order_id,
    so.order_timestamp,
    so.order_amount,
    
    -- 2. HANDLING MISSING & UNSTANDARDIZED TEXT
    -- COALESCE handles true SQL NULLs, but CASE WHEN catches empty strings (''), 
    -- 'N/A', or placeholder text like 'none' to ensure clean business reporting.
    CASE 
        WHEN so.cancellation_reason IS NULL 
          OR TRIM(so.cancellation_reason) IN ('', 'N/A', 'none') 
        THEN 'No Reason Provided'
        ELSE so.cancellation_reason 
    END AS clean_cancellation_reason,
    
    -- 3. NUMERIC BUCKETING & FEATURE ENGINEERING
    -- Groups raw numeric order amounts into business-friendly tier categories:
    -- Small (< $10), Medium ($10-$25), and Large (> $25).
    CASE 
        WHEN so.order_amount < 10.00 THEN 'Small'
        WHEN so.order_amount BETWEEN 10.00 AND 25.00 THEN 'Medium'
        ELSE 'Large'
    END AS order_size_tier

FROM merchants AS merch

-- 4. TABLE RELATIONSHIP & JOIN LOGIC
-- LEFT JOIN ensures all merchants remain in the result set, even if they 
-- haven't logged any surplus orders yet (useful for identifying inactive partners).
LEFT JOIN surplus_orders AS so 
    ON merch.merchant_id = so.merchant_id

-- 5. BUSINESS FILTERING
-- Isolates analysis strictly to completed orders placed in the 2026 calendar year.
WHERE EXTRACT(YEAR FROM so.order_timestamp) = 2026
  AND so.order_status = 'completed';