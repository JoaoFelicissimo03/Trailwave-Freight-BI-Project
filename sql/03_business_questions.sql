-- =====================================================================
-- Trailwave Freight - Supply Chain Report
-- 03_business_questions.sql
-- One query per question the report answers. The Power BI measures are
-- checked against these results.
--
-- Rules used everywhere:
--   * Revenue = item_total (after discount). Margin = profit / revenue.
--   * Canceled and suspected-fraud orders (is_canceled) are left out of
--     every query, as in the Power BI report.
--   * Order counts use DISTINCT order_id, because an order can have several items.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Page 1. Where are we?
-- ---------------------------------------------------------------------

-- Q1. Headline KPIs
WITH delivered AS (
    SELECT order_id, MAX(days_late) AS days_late, BOOL_OR(is_late) AS is_late
    FROM fact_order_items
    WHERE NOT is_canceled
    GROUP BY order_id
)
SELECT
    (SELECT COUNT(DISTINCT order_id) FROM fact_order_items WHERE NOT is_canceled)                  AS orders,
    (SELECT ROUND(SUM(item_total), 0) FROM fact_order_items WHERE NOT is_canceled)                 AS revenue,
    (SELECT ROUND(SUM(profit), 0) FROM fact_order_items WHERE NOT is_canceled)                     AS profit,
    (SELECT ROUND(100 * SUM(profit) / SUM(item_total), 1) FROM fact_order_items WHERE NOT is_canceled) AS margin_pct,
    ROUND(100.0 * COUNT(*) FILTER (WHERE NOT is_late) / COUNT(*), 1)         AS on_time_pct,
    ROUND(AVG(days_late) FILTER (WHERE is_late), 2)                          AS avg_days_late
FROM delivered;

-- Q2. Revenue and profit by month
SELECT d.year_month,
       ROUND(SUM(f.item_total), 0) AS revenue,
       ROUND(SUM(f.profit), 0)     AS profit
FROM fact_order_items f
JOIN dim_date d ON d.date_id = f.order_date_id
WHERE NOT f.is_canceled
GROUP BY d.year_month
ORDER BY d.year_month;

-- Q3. Revenue by market
SELECT g.market,
       ROUND(SUM(f.item_total), 0)                          AS revenue,
       ROUND(100 * SUM(f.item_total) / SUM(SUM(f.item_total)) OVER (), 1) AS revenue_share_pct
FROM fact_order_items f
JOIN dim_geography g ON g.geography_id = f.geography_id
WHERE NOT f.is_canceled
GROUP BY g.market
ORDER BY revenue DESC;

-- ---------------------------------------------------------------------
-- Page 2. Are we on time, and where does it fail?
-- ---------------------------------------------------------------------

-- Q4. Delivery status by shipping mode (distinct orders)
SELECT s.shipping_mode, f.delivery_status, COUNT(DISTINCT f.order_id) AS orders
FROM fact_order_items f
JOIN dim_shipping_mode s ON s.shipping_mode_id = f.shipping_mode_id
WHERE NOT f.is_canceled
GROUP BY s.shipping_mode, f.delivery_status
ORDER BY s.shipping_mode, f.delivery_status;

-- Q5. On-time rate and promised versus real days by shipping mode
WITH delivered AS (
    SELECT DISTINCT ON (order_id)
           order_id, shipping_mode_id, is_late, days_real, days_scheduled
    FROM fact_order_items
    WHERE NOT is_canceled
    ORDER BY order_id
)
SELECT s.shipping_mode,
       COUNT(*)                                                    AS orders,
       s.promised_days,
       ROUND(AVG(d.days_real), 2)                                  AS avg_real_days,
       ROUND(100.0 * COUNT(*) FILTER (WHERE NOT d.is_late) / COUNT(*), 1) AS on_time_pct
FROM delivered d
JOIN dim_shipping_mode s ON s.shipping_mode_id = d.shipping_mode_id
GROUP BY s.shipping_mode, s.promised_days
ORDER BY s.promised_days;

-- Q6. Late rate by customer segment (shows the problem is not the customer)
WITH delivered AS (
    SELECT DISTINCT ON (order_id) order_id, customer_id, is_late
    FROM fact_order_items
    WHERE NOT is_canceled
    ORDER BY order_id
)
SELECT c.customer_segment,
       COUNT(*)                                             AS orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE d.is_late) / COUNT(*), 1) AS late_rate_pct
FROM delivered d
JOIN dim_customer c ON c.customer_id = d.customer_id
GROUP BY c.customer_segment
ORDER BY c.customer_segment;

-- ---------------------------------------------------------------------
-- Page 3. Where does it hurt?
-- ---------------------------------------------------------------------

-- Q7. On-time rate by region and shipping mode
WITH delivered AS (
    SELECT DISTINCT ON (order_id) order_id, geography_id, shipping_mode_id, is_late
    FROM fact_order_items
    WHERE NOT is_canceled
    ORDER BY order_id
)
SELECT g.region, s.shipping_mode,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) FILTER (WHERE NOT d.is_late) / COUNT(*), 1) AS on_time_pct
FROM delivered d
JOIN dim_geography g      ON g.geography_id = d.geography_id
JOIN dim_shipping_mode s  ON s.shipping_mode_id = d.shipping_mode_id
GROUP BY g.region, s.shipping_mode
ORDER BY g.region, s.shipping_mode;

-- Q8. Spread of the late rate across countries (orders >= 100)
WITH delivered AS (
    SELECT DISTINCT ON (order_id) order_id, geography_id, is_late
    FROM fact_order_items
    WHERE NOT is_canceled
    ORDER BY order_id
), by_country AS (
    SELECT g.country, COUNT(*) AS orders,
           100.0 * COUNT(*) FILTER (WHERE d.is_late) / COUNT(*) AS late_rate_pct
    FROM delivered d
    JOIN dim_geography g ON g.geography_id = d.geography_id
    GROUP BY g.country
    HAVING COUNT(*) >= 100
)
SELECT COUNT(*)                          AS countries,
       ROUND(MIN(late_rate_pct)::numeric, 1) AS min_late_pct,
       ROUND(MAX(late_rate_pct)::numeric, 1) AS max_late_pct,
       ROUND(STDDEV(late_rate_pct)::numeric, 1) AS stddev_pct
FROM by_country;

-- Q9. Top 10 products by number of late orders, with revenue exposed
SELECT p.product_name,
       COUNT(DISTINCT f.order_id)      AS late_orders,
       ROUND(SUM(f.item_total), 0)     AS revenue_on_late_orders
FROM fact_order_items f
JOIN dim_product p ON p.product_id = f.product_id
WHERE f.is_late
GROUP BY p.product_name
ORDER BY late_orders DESC
LIMIT 10;

-- ---------------------------------------------------------------------
-- Page 4. Where do we win and lose?
-- ---------------------------------------------------------------------

-- Q10. Profit and margin by category (top 10 by profit)
SELECT p.category_name,
       ROUND(SUM(f.profit), 0)                          AS profit,
       ROUND(100 * SUM(f.profit) / SUM(f.item_total), 1) AS margin_pct
FROM fact_order_items f
JOIN dim_product p ON p.product_id = f.product_id
WHERE NOT f.is_canceled
GROUP BY p.category_name
ORDER BY profit DESC
LIMIT 10;

-- Q11. Margin by market
SELECT g.market,
       ROUND(100 * SUM(f.profit) / SUM(f.item_total), 1) AS margin_pct
FROM fact_order_items f
JOIN dim_geography g ON g.geography_id = f.geography_id
WHERE NOT f.is_canceled
GROUP BY g.market
ORDER BY margin_pct DESC;

-- Q12. Share of loss-making orders (profit below zero) and of items
WITH orders AS (
    SELECT order_id, SUM(profit) AS profit FROM fact_order_items WHERE NOT is_canceled GROUP BY order_id
)
SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE profit < 0) / COUNT(*), 1) AS loss_making_orders_pct,
       (SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE profit < 0) / COUNT(*), 1)
        FROM fact_order_items WHERE NOT is_canceled)                    AS loss_making_items_pct
FROM orders;

-- Q13. Margin by discount band (checks whether discounts explain losses)
SELECT CASE WHEN discount_rate = 0     THEN '0%'
            WHEN discount_rate <= 0.05 THEN '1-5%'
            WHEN discount_rate <= 0.10 THEN '6-10%'
            WHEN discount_rate <= 0.15 THEN '11-15%'
            WHEN discount_rate <= 0.20 THEN '16-20%'
            ELSE '21-25%' END                                  AS discount_band,
       COUNT(*)                                                AS items,
       ROUND(100 * SUM(profit) / SUM(item_total), 1)           AS margin_pct
FROM fact_order_items
WHERE NOT is_canceled
GROUP BY 1
ORDER BY MIN(discount_rate);

-- ---------------------------------------------------------------------
-- Page 5. What is it worth fixing?
-- ---------------------------------------------------------------------

-- Q14. First Class: late orders and revenue on late orders
WITH fc AS (
    SELECT order_id, BOOL_OR(is_late) AS is_late, SUM(item_total) AS revenue
    FROM fact_order_items f
    JOIN dim_shipping_mode s ON s.shipping_mode_id = f.shipping_mode_id
    WHERE s.shipping_mode = 'First Class' AND NOT f.is_canceled
    GROUP BY order_id
)
SELECT COUNT(*)                                       AS first_class_orders,
       COUNT(*) FILTER (WHERE is_late)                AS late_orders,
       ROUND(SUM(revenue) FILTER (WHERE is_late), 0)  AS revenue_on_late_orders
FROM fc;
