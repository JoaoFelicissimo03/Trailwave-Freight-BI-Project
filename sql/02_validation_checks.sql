-- On-Time Rate by Shipping Mode

SELECT 
    fs.shipping_mode,
    COUNT(*) as total_shipments,
    SUM(CASE WHEN fs.late_delivery_flag = FALSE THEN 1 ELSE 0 END) as on_time,
    ROUND(SUM(CASE WHEN fs.late_delivery_flag = FALSE THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as on_time_rate
FROM fact_shipments fs
GROUP BY fs.shipping_mode
ORDER BY on_time_rate DESC;

-- Revenue and margin by market

SELECT 
    dr.market,
    ROUND(SUM(fo.total_revenue)::numeric, 2) as total_revenue,
    ROUND(AVG(fo.profit_margin)::numeric, 4) as avg_margin,
    COUNT(*) as total_orders
FROM fact_orders fo
JOIN dim_region dr ON fo.region_id = dr.region_id
GROUP BY dr.market
ORDER BY total_revenue DESC;

--  Top 5 products with more delays

SELECT 
    dp.product_name,
    COUNT(*) as late_deliveries
FROM fact_shipments fs
JOIN fact_orders fo ON fs.order_id = fo.order_id
JOIN dim_product dp ON fo.product_id = dp.product_id
WHERE fs.late_delivery_flag = TRUE
GROUP BY dp.product_name
ORDER BY late_deliveries DESC
LIMIT 5;

-- Margin evolution per YEAR


SELECT 
    dd.year,
    ROUND(AVG(fo.profit_margin)::numeric, 4) as avg_margin,
    ROUND(SUM(fo.total_revenue)::numeric, 2) as total_revenue
FROM fact_orders fo
JOIN dim_date dd ON fo.date_id = dd.date_id
GROUP BY dd.year
ORDER BY dd.year;

-- Delays per segment

SELECT 
    dc.customer_segment,
    COUNT(*) as total_shipments,
    SUM(CASE WHEN fs.late_delivery_flag = TRUE THEN 1 ELSE 0 END) as late_deliveries,
    ROUND(SUM(CASE WHEN fs.late_delivery_flag = TRUE THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as late_rate
FROM fact_shipments fs
JOIN fact_orders fo ON fs.order_id = fo.order_id
JOIN dim_customer dc ON fo.customer_id = dc.customer_id
GROUP BY dc.customer_segment
ORDER BY late_rate DESC;
