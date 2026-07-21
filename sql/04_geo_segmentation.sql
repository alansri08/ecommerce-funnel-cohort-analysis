-- Geography segmentation: for the top 5 states by order volume, compare
-- repeat-purchase rate (by customer_unique_id) and average order value
-- (SUM(payment_value) per order_id, since payments have multiple rows
-- per order due to installments).
-- Repeat rate and avg order value are aggregated in separate CTEs before
-- the final join so that fanning out per-order rows against per-customer
-- rows can't inflate the repeat-customer counts.

WITH order_values AS (
    SELECT order_id, SUM(payment_value) AS order_value
    FROM read_csv_auto('data/olist_order_payments_dataset.csv')
    GROUP BY 1
),
orders_full AS (
    SELECT
        o.order_id,
        c.customer_unique_id,
        c.customer_state,
        ov.order_value
    FROM read_csv_auto('data/olist_orders_dataset.csv') o
    JOIN read_csv_auto('data/olist_customers_dataset.csv') c
      ON o.customer_id = c.customer_id
    LEFT JOIN order_values ov
      ON o.order_id = ov.order_id
),
state_volume AS (
    SELECT customer_state, COUNT(*) AS order_count
    FROM orders_full
    GROUP BY 1
    ORDER BY order_count DESC
    LIMIT 5
),
customer_state_stats AS (
    SELECT
        customer_unique_id,
        customer_state,
        COUNT(DISTINCT order_id) AS total_orders
    FROM orders_full
    WHERE customer_state IN (SELECT customer_state FROM state_volume)
    GROUP BY 1, 2
),
repeat_by_state AS (
    SELECT
        customer_state,
        COUNT(*) AS customers,
        SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END) AS repeat_customers
    FROM customer_state_stats
    GROUP BY 1
),
aov_by_state AS (
    SELECT customer_state, AVG(order_value) AS avg_order_value
    FROM orders_full
    WHERE customer_state IN (SELECT customer_state FROM state_volume)
    GROUP BY 1
)
SELECT
    sv.customer_state,
    sv.order_count,
    rbs.customers,
    rbs.repeat_customers,
    ROUND(100.0 * rbs.repeat_customers / rbs.customers, 2) AS repeat_purchase_rate_pct,
    ROUND(av.avg_order_value, 2)                            AS avg_order_value
FROM state_volume sv
JOIN repeat_by_state rbs ON sv.customer_state = rbs.customer_state
JOIN aov_by_state av     ON sv.customer_state = av.customer_state
ORDER BY sv.order_count DESC;
