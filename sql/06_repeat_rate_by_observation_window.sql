-- Does right-censoring distort the headline "overall repeat purchase rate"?
-- Customers whose first order was very recent (e.g. summer 2018) have had
-- little to no time to place a second order before the dataset ends, which
-- mechanically drags down any repeat-rate figure computed across ALL
-- customers regardless of acquisition date. This splits customers into
-- those with at least 6 full months between their first order and the
-- last complete month in the data (2018-08-01, see 02_cohort_retention.sql
-- for why Sept/Oct 2018 are excluded as trailing artifacts) vs. those
-- without, and compares repeat-purchase rate between the two groups.

WITH orders_customers AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
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
per_customer AS (
    SELECT
        oc.customer_unique_id,
        fo.cohort_month,
        COUNT(DISTINCT oc.order_id) AS total_orders
    FROM orders_customers oc
    JOIN first_order fo ON oc.customer_unique_id = fo.customer_unique_id
    GROUP BY 1, 2
)
SELECT
    CASE
        WHEN cohort_month <= DATE '2018-02-01' THEN '6mo+ observation window'
        ELSE 'under 6mo observation window (censored)'
    END AS observation_bucket,
    COUNT(*)                                                           AS customers,
    SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END)                  AS repeat_customers,
    ROUND(100.0 * SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END)
        / COUNT(*), 2)                                                 AS repeat_purchase_rate_pct
FROM per_customer
GROUP BY 1
ORDER BY 1;
