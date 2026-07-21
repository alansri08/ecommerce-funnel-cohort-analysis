-- Behavioral cohort: does satisfaction on the FIRST order predict repeat purchase?
-- Customers (by customer_unique_id) are split by their first order's review_score
-- into 4-5 stars (satisfied) vs 1-3 stars (unsatisfied), then we compare what
-- share of each group ever placed a second order.
-- Note: 547 order_ids in the raw reviews file have more than one review row
-- (202 with conflicting scores), so reviews are deduped to the most recent
-- review per order before joining.

WITH reviews_deduped AS (
    SELECT order_id, review_score
    FROM (
        SELECT
            order_id,
            review_score,
            ROW_NUMBER() OVER (
                PARTITION BY order_id
                ORDER BY review_creation_date DESC, review_id
            ) AS rn
        FROM read_csv_auto('data/olist_order_reviews_dataset.csv')
    )
    WHERE rn = 1
),
orders_customers AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp
    FROM read_csv_auto('data/olist_orders_dataset.csv') o
    JOIN read_csv_auto('data/olist_customers_dataset.csv') c
      ON o.customer_id = c.customer_id
),
ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp) AS rn,
        COUNT(*) OVER (PARTITION BY customer_unique_id) AS total_orders
    FROM orders_customers
),
first_orders AS (
    SELECT customer_unique_id, order_id, total_orders
    FROM ranked
    WHERE rn = 1
),
first_order_reviews AS (
    SELECT
        fo.customer_unique_id,
        fo.total_orders,
        r.review_score,
        CASE WHEN r.review_score >= 4 THEN '4-5 stars (satisfied)'
             ELSE '1-3 stars (unsatisfied)' END AS review_group
    FROM first_orders fo
    JOIN reviews_deduped r
      ON fo.order_id = r.order_id
)
SELECT
    review_group,
    COUNT(*) AS customers,
    SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(100.0 * SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS repeat_purchase_rate_pct
FROM first_order_reviews
GROUP BY 1
ORDER BY 1;
