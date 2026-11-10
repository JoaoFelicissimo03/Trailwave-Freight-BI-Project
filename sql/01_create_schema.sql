-- =====================================================================
-- Trailwave Freight - Supply Chain Report
-- 01_create_schema.sql
-- Star schema: one fact table (order item grain) and five dimensions.
-- Safe to re-run: drops and recreates all objects.
-- =====================================================================

DROP TABLE IF EXISTS fact_order_items CASCADE;
DROP TABLE IF EXISTS dim_shipping_mode CASCADE;
DROP TABLE IF EXISTS dim_geography CASCADE;
DROP TABLE IF EXISTS dim_customer CASCADE;
DROP TABLE IF EXISTS dim_product CASCADE;
DROP TABLE IF EXISTS dim_date CASCADE;

-- ---------------------------------------------------------------------
-- Dimensions
-- ---------------------------------------------------------------------

-- One row per calendar day. date_id is the integer form YYYYMMDD.
CREATE TABLE dim_date (
    date_id       INTEGER      PRIMARY KEY,
    full_date     DATE         NOT NULL UNIQUE,
    year          SMALLINT     NOT NULL,
    quarter       SMALLINT     NOT NULL,
    month         SMALLINT     NOT NULL,
    month_name    VARCHAR(9)   NOT NULL,
    year_month    CHAR(7)      NOT NULL,      -- e.g. 2016-03
    month_start   DATE         NOT NULL,
    week_of_year  SMALLINT     NOT NULL,
    day_of_week   SMALLINT     NOT NULL,      -- 1 = Monday ... 7 = Sunday
    day_name      VARCHAR(9)   NOT NULL,
    is_weekend    BOOLEAN      NOT NULL
);

-- One row per product. Category and department are kept on the product
-- (each product belongs to exactly one category and department).
CREATE TABLE dim_product (
    product_id       INTEGER        PRIMARY KEY,
    product_name     VARCHAR(150)   NOT NULL,
    category_id      INTEGER        NOT NULL,
    category_name    VARCHAR(80)    NOT NULL,
    department_id    INTEGER        NOT NULL,
    department_name  VARCHAR(80)    NOT NULL,
    unit_price       NUMERIC(10,2)  NOT NULL
);

-- One row per customer. Names, emails, passwords and street addresses
-- are deliberately not loaded: the report does not need them.
CREATE TABLE dim_customer (
    customer_id       INTEGER      PRIMARY KEY,
    customer_segment  VARCHAR(20)  NOT NULL,
    customer_city     VARCHAR(80),
    customer_state    VARCHAR(20),
    customer_country  VARCHAR(40)
);

-- One row per market, region and destination country combination.
-- Country names are translated from Spanish to English in the ETL.
CREATE TABLE dim_geography (
    geography_id  SMALLINT     PRIMARY KEY,
    market        VARCHAR(20)  NOT NULL,
    region        VARCHAR(40)  NOT NULL,
    country       VARCHAR(60)  NOT NULL,
    UNIQUE (market, region, country)
);

-- One row per shipping mode, with the delivery time Trailwave promises.
CREATE TABLE dim_shipping_mode (
    shipping_mode_id  SMALLINT     PRIMARY KEY,
    shipping_mode     VARCHAR(20)  NOT NULL UNIQUE,
    promised_days     SMALLINT     NOT NULL
);

-- ---------------------------------------------------------------------
-- Fact table: one row per order item (line of an order)
-- ---------------------------------------------------------------------
-- Delivery fields (shipping mode, days, status) repeat on every item of
-- the same order. Count orders with DISTINCT order_id in delivery KPIs.
CREATE TABLE fact_order_items (
    order_item_id      BIGINT         PRIMARY KEY,
    order_id           BIGINT         NOT NULL,
    order_date_id      INTEGER        NOT NULL REFERENCES dim_date (date_id),
    ship_date_id       INTEGER        NOT NULL REFERENCES dim_date (date_id),
    customer_id        INTEGER        NOT NULL REFERENCES dim_customer (customer_id),
    product_id         INTEGER        NOT NULL REFERENCES dim_product (product_id),
    geography_id       SMALLINT       NOT NULL REFERENCES dim_geography (geography_id),
    shipping_mode_id   SMALLINT       NOT NULL REFERENCES dim_shipping_mode (shipping_mode_id),

    order_status       VARCHAR(20)    NOT NULL,
    delivery_status    VARCHAR(20)    NOT NULL,
    is_canceled        BOOLEAN        NOT NULL,   -- shipping canceled (canceled or suspected fraud)
    is_late            BOOLEAN        NOT NULL,   -- delivered later than promised

    days_real          SMALLINT       NOT NULL,   -- actual shipping days
    days_scheduled     SMALLINT       NOT NULL,   -- promised shipping days
    days_late          SMALLINT,                  -- GREATEST(real - promised, 0); NULL when canceled

    quantity           SMALLINT       NOT NULL CHECK (quantity > 0),
    unit_price         NUMERIC(10,2)  NOT NULL,
    discount_amount    NUMERIC(10,2)  NOT NULL,
    discount_rate      NUMERIC(5,4)   NOT NULL,
    sales              NUMERIC(12,2)  NOT NULL,   -- before discount
    item_total         NUMERIC(12,2)  NOT NULL,   -- after discount (revenue)
    profit             NUMERIC(12,2)  NOT NULL
);

CREATE INDEX idx_fact_order_id       ON fact_order_items (order_id);
CREATE INDEX idx_fact_order_date     ON fact_order_items (order_date_id);
CREATE INDEX idx_fact_ship_date      ON fact_order_items (ship_date_id);
CREATE INDEX idx_fact_customer       ON fact_order_items (customer_id);
CREATE INDEX idx_fact_product        ON fact_order_items (product_id);
CREATE INDEX idx_fact_geography      ON fact_order_items (geography_id);
CREATE INDEX idx_fact_shipping_mode  ON fact_order_items (shipping_mode_id);
