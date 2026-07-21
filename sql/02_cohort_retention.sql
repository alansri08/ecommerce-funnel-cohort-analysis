-- Monthly acquisition cohort retention.
-- Customers are grouped by the month of their FIRST order (cohort_month),
-- using customer_unique_id since customer_id is per-order in this dataset.
-- For every cohort, we track what % of the original cohort placed ANY order
-- in each subsequent month (month_number = months since first purchase).

WITH orders_customers AS (
    SELECT
        c.customer_unique_id,
        o.order_purchase_timestamp
    FROM read_csv_auto('data/olist_orders_dataset.csv') o
    JOIN read_csv_auto('data/olist_customers_dataset.csv') c
      ON o.customer_id = c.customer_id
),
first_order AS (
    SELECT
        customer_unique_id,
        DATE_TRUNC('month', MIN(order_purchase_timestamp)) AS cohort_month
    FROM orders_customers
    GROUP BY 1
),
order_activity AS (
    SELECT
        oc.customer_unique_id,
        fo.cohort_month,
        DATEDIFF(
            'month',
            fo.cohort_month,
            DATE_TRUNC('month', oc.order_purchase_timestamp)
        ) AS month_number
    FROM orders_customers oc
    JOIN first_order fo ON oc.customer_unique_id = fo.customer_unique_id
),
cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT customer_unique_id) AS cohort_customers
    FROM first_order
    GROUP BY 1
),
retention AS (
    SELECT
        cohort_month,
        month_number,
        COUNT(DISTINCT customer_unique_id) AS active_customers
    FROM order_activity
    GROUP BY 1, 2
)
SELECT
    r.cohort_month,
    r.month_number,
    cs.cohort_customers,
    r.active_customers,
    ROUND(100.0 * r.active_customers / cs.cohort_customers, 2) AS retention_pct
FROM retention r
JOIN cohort_size cs ON r.cohort_month = cs.cohort_month
ORDER BY r.cohort_month, r.month_number;
