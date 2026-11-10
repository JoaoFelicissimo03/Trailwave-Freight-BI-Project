-- 04_measure_checks.sql
-- Reference numbers for every DAX measure in powerbi/measures.dax.
-- Each query should return the same values as the matching DAX query in Power BI.
-- Canceled and suspected-fraud orders are excluded everywhere, as in the report.


-- T1: overall
WITH o AS (
    SELECT order_id, bool_or(is_late) AS late, max(days_late) AS dl, max(days_real) AS dr,
           max(days_scheduled) AS ds, sum(item_total) AS rev, sum(profit) AS pr
    FROM fact_order_items WHERE NOT is_canceled GROUP BY order_id
)
SELECT count(*) AS orders,
       count(*) FILTER (WHERE late) AS late_orders,
       count(*) FILTER (WHERE NOT late) AS on_time_orders,
       round(count(*) FILTER (WHERE NOT late)::numeric / count(*), 6) AS on_time_pct,
       round(avg(dl) FILTER (WHERE late), 6) AS avg_days_late,
       round(avg(dr), 6) AS avg_days_real,
       round(avg(ds), 6) AS avg_days_promised,
       round(sum(rev), 2) AS revenue,
       round(sum(pr), 2) AS profit,
       round(sum(pr) / sum(rev), 6) AS margin,
       round(sum(rev) FILTER (WHERE late), 2) AS rev_late,
       count(*) FILTER (WHERE pr < 0) AS loss_orders,
       round(count(*) FILTER (WHERE pr < 0)::numeric / count(*), 6) AS loss_pct
FROM o;

-- T2: data note
SELECT count(DISTINCT order_id) AS all_orders,
       count(DISTINCT order_id) FILTER (WHERE is_canceled) AS canceled_orders
FROM fact_order_items;

-- T3: by shipping mode
WITH o AS (
    SELECT f.order_id, s.shipping_mode, bool_or(f.is_late) AS late, max(f.days_late) AS dl,
           max(f.days_real) AS dr, max(f.days_scheduled) AS ds, sum(f.item_total) AS rev
    FROM fact_order_items f JOIN dim_shipping_mode s USING (shipping_mode_id)
    WHERE NOT f.is_canceled GROUP BY f.order_id, s.shipping_mode
)
SELECT shipping_mode, count(*) AS orders, count(*) FILTER (WHERE late) AS late_orders,
       round(count(*) FILTER (WHERE NOT late)::numeric / count(*), 6) AS on_time_pct,
       round(count(*) FILTER (WHERE late)::numeric / sum(count(*) FILTER (WHERE late)) OVER (), 6) AS late_share,
       round(avg(dl) FILTER (WHERE late), 6) AS avg_days_late,
       round(avg(dr), 6) AS avg_days_real, round(avg(ds), 6) AS avg_days_promised,
       round(sum(rev), 2) AS revenue, round(sum(rev) FILTER (WHERE late), 2) AS rev_late
FROM o GROUP BY shipping_mode ORDER BY shipping_mode;

-- T4: by market
WITH i AS (
    SELECT f.*, g.market FROM fact_order_items f JOIN dim_geography g USING (geography_id)
    WHERE NOT f.is_canceled
), o AS (
    SELECT order_id, market, bool_or(is_late) AS late, sum(profit) AS pr FROM i GROUP BY 1, 2
)
SELECT m.market, m.revenue, m.profit, m.margin, m.share, x.orders, x.on_time_pct, x.loss_orders
FROM (
    SELECT market, round(sum(item_total), 2) AS revenue, round(sum(profit), 2) AS profit,
           round(sum(profit) / sum(item_total), 6) AS margin,
           round(sum(item_total) / sum(sum(item_total)) OVER (), 6) AS share
    FROM i GROUP BY market
) m JOIN (
    SELECT market, count(*) AS orders,
           round(count(*) FILTER (WHERE NOT late)::numeric / count(*), 6) AS on_time_pct,
           count(*) FILTER (WHERE pr < 0) AS loss_orders
    FROM o GROUP BY market
) x USING (market)
ORDER BY m.market;

-- T5: by category
WITH i AS (
    SELECT f.*, p.category_name FROM fact_order_items f JOIN dim_product p USING (product_id)
    WHERE NOT f.is_canceled
), o AS (
    SELECT order_id, category_name, bool_or(is_late) AS late, sum(profit) AS pr, sum(item_total) AS rev
    FROM i GROUP BY 1, 2
)
SELECT category_name, count(*) AS orders,
       round(count(*) FILTER (WHERE late)::numeric / count(*), 6) AS late_rate,
       round(sum(rev), 2) AS revenue, round(sum(pr), 2) AS profit,
       round(sum(rev) FILTER (WHERE late), 2) AS rev_late,
       count(*) FILTER (WHERE pr < 0) AS loss_orders
FROM o GROUP BY category_name ORDER BY category_name;

-- T6: by segment
WITH o AS (
    SELECT f.order_id, c.customer_segment, bool_or(f.is_late) AS late
    FROM fact_order_items f JOIN dim_customer c USING (customer_id)
    WHERE NOT f.is_canceled GROUP BY 1, 2
)
SELECT customer_segment, count(*) AS orders,
       round(count(*) FILTER (WHERE late)::numeric / count(*), 6) AS late_rate
FROM o GROUP BY 1 ORDER BY 1;

-- T7: by month
SELECT d.year_month, count(DISTINCT f.order_id) AS orders, round(sum(f.item_total), 2) AS revenue,
       CASE WHEN d.full_date <= DATE '2017-09-30' THEN round(sum(f.item_total), 2) END AS revenue_to_sep17
FROM fact_order_items f JOIN dim_date d ON d.date_id = f.order_date_id
WHERE NOT f.is_canceled
GROUP BY d.year_month, (d.full_date <= DATE '2017-09-30')
ORDER BY d.year_month;

-- T8: region x mode on-time (Western Europe, Oceania)
WITH o AS (
    SELECT f.order_id, g.region, s.shipping_mode, bool_or(f.is_late) AS late
    FROM fact_order_items f JOIN dim_geography g USING (geography_id) JOIN dim_shipping_mode s USING (shipping_mode_id)
    WHERE NOT f.is_canceled AND g.region IN ('Western Europe', 'Oceania') GROUP BY 1, 2, 3
)
SELECT region, shipping_mode, count(*) AS orders,
       round(count(*) FILTER (WHERE NOT late)::numeric / count(*), 6) AS on_time_pct
FROM o GROUP BY 1, 2 ORDER BY 1, 2;

-- T9: what-if at several targets (all data, and Europe only)
WITH o AS (
    SELECT f.order_id, g.market, s.shipping_mode, bool_or(f.is_late) AS late, sum(f.item_total) AS rev
    FROM fact_order_items f JOIN dim_shipping_mode s USING (shipping_mode_id) JOIN dim_geography g USING (geography_id)
    WHERE NOT f.is_canceled GROUP BY 1, 2, 3
), scope AS (
    SELECT 'All' AS scope, * FROM o UNION ALL SELECT 'Europe', * FROM o WHERE market = 'Europe'
), base AS (
    SELECT scope, count(*) AS orders, count(*) FILTER (WHERE NOT late) AS on_time,
           count(*) FILTER (WHERE late) AS late_orders, sum(rev) FILTER (WHERE late) AS rev_late,
           count(*) FILTER (WHERE shipping_mode = 'First Class') AS fc_orders,
           count(*) FILTER (WHERE shipping_mode = 'First Class' AND NOT late) AS fc_on_time,
           count(*) FILTER (WHERE shipping_mode = 'First Class' AND late) AS fc_late,
           sum(rev) FILTER (WHERE shipping_mode = 'First Class' AND late) AS fc_rev_late
    FROM scope GROUP BY scope
), t AS (SELECT unnest(ARRAY[0, 0.25, 0.6, 1.0]) AS target)
SELECT scope, target,
       greatest(0, round(fc_orders * target - fc_on_time)) AS avoided,
       round((on_time + greatest(0, round(fc_orders * target - fc_on_time)))::numeric / orders, 6) AS on_time_with_target,
       round(rev_late - greatest(0, round(fc_orders * target - fc_on_time)) / fc_late * fc_rev_late, 2) AS rev_late_with_target
FROM base CROSS JOIN t ORDER BY scope, target;
