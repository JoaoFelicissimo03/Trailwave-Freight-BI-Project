-- =====================================================================
-- Trailwave Freight - Supply Chain Report
-- 02_validation_checks.sql
-- Data quality checks after the ETL. Every query returns the rows that
-- break a rule, so an empty result means the check passed.
-- =====================================================================

-- 1. Row counts per table (reference: 180,519 items, 65,752 orders)
SELECT 'fact_order_items' AS table_name, COUNT(*) AS row_count FROM fact_order_items
UNION ALL SELECT 'distinct orders',          COUNT(DISTINCT order_id) FROM fact_order_items
UNION ALL SELECT 'dim_date',                 COUNT(*) FROM dim_date
UNION ALL SELECT 'dim_product',              COUNT(*) FROM dim_product
UNION ALL SELECT 'dim_customer',             COUNT(*) FROM dim_customer
UNION ALL SELECT 'dim_geography',            COUNT(*) FROM dim_geography
UNION ALL SELECT 'dim_shipping_mode',        COUNT(*) FROM dim_shipping_mode;

-- 2. Orders whose delivery fields differ between items (expect 0 rows)
SELECT order_id
FROM fact_order_items
GROUP BY order_id
HAVING COUNT(DISTINCT shipping_mode_id) > 1
    OR COUNT(DISTINCT days_real) > 1
    OR COUNT(DISTINCT delivery_status) > 1
    OR COUNT(DISTINCT is_late) > 1;

-- 3. Canceled items marked as late (expect 0 rows)
SELECT order_item_id FROM fact_order_items WHERE is_canceled AND is_late;

-- 4. Late items without a late delivery status (expect 0 rows)
SELECT order_item_id FROM fact_order_items
WHERE is_late <> (delivery_status = 'Late delivery');

-- 5. Items shipped before they were ordered (expect 0 rows)
SELECT f.order_item_id
FROM fact_order_items f
WHERE f.ship_date_id < f.order_date_id;

-- 6. Item total is not sales minus discount, beyond 2 cents (expect 0 rows)
SELECT order_item_id
FROM fact_order_items
WHERE ABS(item_total - (sales - discount_amount)) > 0.02;

-- 7. Promised days in the fact table differ from the shipping mode (expect 0 rows)
SELECT f.order_item_id
FROM fact_order_items f
JOIN dim_shipping_mode s ON s.shipping_mode_id = f.shipping_mode_id
WHERE f.days_scheduled <> s.promised_days;

-- 8. days_late is inconsistent with real and promised days (expect 0 rows)
SELECT order_item_id
FROM fact_order_items
WHERE NOT is_canceled
  AND days_late <> GREATEST(days_real - days_scheduled, 0);

-- 9. Countries that still look Spanish (expect 0 rows)
SELECT DISTINCT country
FROM dim_geography
WHERE country ~ '[áéíóúñÁÉÍÓÚ]';

-- 10. Dates outside the loaded calendar year range (expect 0 rows)
SELECT DISTINCT d.year
FROM fact_order_items f
JOIN dim_date d ON d.date_id = f.order_date_id
WHERE d.year NOT BETWEEN 2015 AND 2018;
