-- Estimated order value at risk from the Approved -> Shipped funnel leak
-- (the biggest single drop-off identified in sql/01_order_funnel.sql).
-- Average order value uses the FULL dataset (all orders, all states) via
-- SUM(payment_value) per order_id, not just the top-5-state subset used in
-- sql/04_geo_segmentation.sql. The leak count is recomputed here from the
-- same stage timestamps as the funnel query rather than hardcoded, so this
-- stays correct if the underlying data changes.

WITH stage_counts AS (
    SELECT
        COUNT(order_approved_at)            AS approved,
        COUNT(order_delivered_carrier_date) AS shipped
    FROM read_csv_auto('data/olist_orders_dataset.csv')
),
approved_to_shipped_leak AS (
    SELECT approved - shipped AS leak_count
    FROM stage_counts
),
order_values AS (
    SELECT order_id, SUM(payment_value) AS order_value
    FROM read_csv_auto('data/olist_order_payments_dataset.csv')
    GROUP BY 1
),
avg_value AS (
    SELECT
        COUNT(*)        AS orders_with_payment,
        AVG(order_value) AS avg_order_value
    FROM order_values
)
SELECT
    l.leak_count,
    v.orders_with_payment,
    ROUND(v.avg_order_value, 2)               AS avg_order_value,
    ROUND(l.leak_count * v.avg_order_value, 2) AS estimated_value_at_risk
FROM approved_to_shipped_leak l
CROSS JOIN avg_value v;
