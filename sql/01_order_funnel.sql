-- Order funnel: placed -> approved -> shipped -> delivered
-- Stage progression is measured from the timestamp columns in olist_orders_dataset
-- (order_status is a terminal snapshot, e.g. a canceled order that was already
-- shipped would not show "shipped" in order_status, so timestamps are the
-- reliable signal for how far an order actually progressed).

WITH stage_counts AS (
    SELECT
        COUNT(*)                                AS placed,
        COUNT(order_approved_at)                AS approved,
        COUNT(order_delivered_carrier_date)      AS shipped,
        COUNT(order_delivered_customer_date)     AS delivered
    FROM read_csv_auto('data/olist_orders_dataset.csv')
),
funnel AS (
    SELECT 1 AS stage_order, 'Order Placed' AS stage, placed  AS orders FROM stage_counts
    UNION ALL
    SELECT 2, 'Approved',  approved  FROM stage_counts
    UNION ALL
    SELECT 3, 'Shipped',   shipped   FROM stage_counts
    UNION ALL
    SELECT 4, 'Delivered', delivered FROM stage_counts
)
SELECT
    stage_order,
    stage,
    orders,
    ROUND(100.0 * orders / FIRST_VALUE(orders) OVER (ORDER BY stage_order), 2)               AS pct_of_total,
    LAG(orders) OVER (ORDER BY stage_order) - orders                                          AS dropoff_count,
    ROUND(100.0 * (LAG(orders) OVER (ORDER BY stage_order) - orders)
        / NULLIF(LAG(orders) OVER (ORDER BY stage_order), 0), 2)                              AS dropoff_pct_of_prev_stage
FROM funnel
ORDER BY stage_order;
