CREATE TABLE dim_date (
    date_id     SERIAL PRIMARY KEY,
    full_date   DATE NOT NULL,
    year        INT,
    quarter     INT,
    month       INT,
    month_name  VARCHAR(20),
    week        INT,
    is_weekend  BOOLEAN
);

CREATE TABLE dim_product (
    product_id    SERIAL PRIMARY KEY,
    product_name  VARCHAR(150),
    category      VARCHAR(100),
    department    VARCHAR(100),
    unit_cost     NUMERIC(10,2)
);

CREATE TABLE dim_customer (
    customer_id       SERIAL PRIMARY KEY,
    customer_segment  VARCHAR(50),
    market            VARCHAR(50),
    country           VARCHAR(100)
);

CREATE TABLE dim_region (
    region_id  SERIAL PRIMARY KEY,
    region     VARCHAR(100),
    country    VARCHAR(100),
    market     VARCHAR(50)
);


CREATE TABLE fact_orders (
    order_id          SERIAL PRIMARY KEY,
    customer_id       INT REFERENCES dim_customer(customer_id),
    product_id        INT REFERENCES dim_product(product_id),
    date_id           INT REFERENCES dim_date(date_id),
    region_id         INT REFERENCES dim_region(region_id),
    quantity_ordered  INT,
    unit_price        NUMERIC(10,2),
    total_revenue     NUMERIC(12,2),
    profit_margin     NUMERIC(10,4)
);


CREATE TABLE fact_shipments (
    shipment_id                 SERIAL PRIMARY KEY,
    order_id                    INT REFERENCES fact_orders(order_id),
    date_id                     INT REFERENCES dim_date(date_id),
    shipping_mode               VARCHAR(50),
    days_for_shipping_real      INT,
    days_for_shipment_scheduled INT,
    late_delivery_flag          BOOLEAN,
    shipping_cost               NUMERIC(10,2)
);

-- ======================================
-- RUN THE JUPYTER NOTEBOOK FILE
-- TO POPULATE THE TABLES!
-- ======================================

-- Check if the tables are populated

Select 'dim_customer', COUNT(*)
FROM dim_customer

UNION ALL 

Select 'dim_date',COUNT(*)
FROM dim_date

UNION ALL 

Select 'dim_product', COUNT(*)
FROM dim_product

UNION ALL 

Select 'dim_region',COUNT(*)
FROM dim_region

UNION ALL

Select 'fact_orders', COUNT(*)
FROM fact_orders

UNION ALL 

Select 'fact_shipments', COUNT(*)
FROM fact_shipments;

SELECT customer_id, COUNT(*) 
FROM dim_customer 
GROUP BY customer_id 
HAVING COUNT(*) > 1
LIMIT 5;

-- Quick sanity check
SELECT 
    fo.order_id,
    dc.customer_segment,
    dp.product_name,
    dd.full_date,
    dr.region,
    fo.total_revenue,
    fs.shipping_mode,
    fs.late_delivery_flag
FROM fact_orders fo
JOIN dim_customer dc ON fo.customer_id = dc.customer_id
JOIN dim_product  dp ON fo.product_id  = dp.product_id
JOIN dim_date     dd ON fo.date_id     = dd.date_id
JOIN dim_region   dr ON fo.region_id   = dr.region_id
JOIN fact_shipments fs ON fo.order_id  = fs.order_id
LIMIT 10;

