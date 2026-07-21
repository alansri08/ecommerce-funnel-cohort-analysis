-- Baseline metric: across the full ~2-year dataset window, what share of
-- customers (by customer_unique_id) ever placed more than one order at all,
-- regardless of which month? Used as a reference point alongside the
-- month-by-month cohort retention table in 02_cohort_retention.sql.

WITH orders_customers AS (
    SELECT
        c.customer_unique_id,
        o.order_id
    FROM read_csv_auto('data/olist_orders_dataset.csv') o
    JOIN read_csv_auto('data/olist_customers_dataset.csv') c
      ON o.customer_id = c.customer_id
),
per_customer AS (
    SELECT customer_unique_id, COUNT(DISTINCT order_id) AS total_orders
    FROM orders_customers
    GROUP BY 1
)
SELECT
    COUNT(*)                                                            AS total_customers,
    SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END)                   AS repeat_customers,
    ROUND(100.0 * SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END)
        / COUNT(*), 2)                                                  AS overall_repeat_rate_pct
FROM per_customer;
