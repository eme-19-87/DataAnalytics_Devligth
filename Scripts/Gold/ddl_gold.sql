CREATE SCHEMA IF NOT EXISTS gold;

/* 
    Dimension: Customers
    Surrogate keys generated using ROW_NUMBER().
    Source: silver.olist_customers
*/
CREATE OR REPLACE VIEW gold.dim_customers AS
SELECT
    ROW_NUMBER() OVER (ORDER BY customer_id) AS customer_key,
    customer_id,
    customer_unique_id,
    customer_city,
    customer_state,
    COALESCE(g.geolocation_lat,0) AS "customer_city_lat",
    COALESCE(g.geolocation_lng,0) AS "customer_city_lng"
FROM silver.olist_customers cs
LEFT JOIN silver.olist_geolocation g on customer_zip_code_prefix=geolocation_zip_code_prefix;

/*
    Dimension: Sellers
    Surrogate keys generated using ROW_NUMBER().
    Source: silver.olist_sellers
*/

CREATE OR REPLACE VIEW gold.dim_sellers AS

SELECT
    ROW_NUMBER() OVER (ORDER BY seller_id) AS seller_key,
    seller_id,
    seller_city,
    seller_state,
    COALESCE(g.geolocation_lat,0) AS "seller_city_lat",
    COALESCE(g.geolocation_lng,0) AS "seller_city_lng"
FROM silver.olist_sellers cs
LEFT JOIN silver.olist_geolocation g on seller_zip_code_prefix=geolocation_zip_code_prefix;

CREATE OR REPLACE VIEW gold.dim_products AS
/*
    Dimension: Products
    Generates surrogate key using ROW_NUMBER().
    Source: silver.olist_products
*/
SELECT
    ROW_NUMBER() OVER (ORDER BY product_id) AS product_key,
    product_id,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,
    product_category_name
FROM silver.olist_products;

CREATE OR REPLACE VIEW gold.dim_status AS
/*
    Dimension: Order Status
    Includes status_group for simplified classification:
        - final
        - in_progress
        - canceled
    Source: silver.olist_orders
*/
WITH status_raw AS (
    SELECT DISTINCT order_status AS status
    FROM silver.olist_orders
)
SELECT
    ROW_NUMBER() OVER (ORDER BY status) AS status_key,
    status,
    CASE 
        WHEN status IN ('delivered') THEN 'final'
        WHEN status IN ('shipped','approved','invoiced','processing') THEN 'in_progress'
        ELSE 'canceled'
    END AS status_group
FROM status_raw;


CREATE OR REPLACE VIEW gold.dim_calendar AS
/*
    Dimension: Calendar
    Enriched calendar for advanced analytical queries (BI, DW, Metabase).
*/
WITH dates AS (
    SELECT DISTINCT
        order_purchase_timestamp::date AS date_ymd
    FROM silver.olist_orders
)
SELECT
    ROW_NUMBER() OVER (ORDER BY date_ymd) AS date_key,
    date_ymd,
    EXTRACT(YEAR FROM date_ymd) AS date_year,
    EXTRACT(MONTH FROM date_ymd) AS date_month,
    EXTRACT(DAY FROM date_ymd) AS date_day,
    TO_CHAR(date_ymd, 'Month') AS month_name,
    TO_CHAR(date_ymd, 'Day') AS date_weekday,
    EXTRACT(ISODOW FROM date_ymd) AS weekday_iso_number,
    EXTRACT(WEEK FROM date_ymd) AS week_of_year,
    EXTRACT(DOY FROM date_ymd) AS day_of_year,
    CEIL(EXTRACT(MONTH FROM date_ymd) / 3.0) AS quarter,
    CASE WHEN EXTRACT(ISODOW FROM date_ymd) IN (6,7) THEN TRUE ELSE FALSE END AS is_weekend,
    FALSE AS is_holiday, -- Placeholder for future holiday enrichment
    TO_CHAR(date_ymd, 'YYYYMMDD') AS yyyymmdd,
    TO_CHAR(date_ymd, 'YYYYMM') AS yyyymm,
    TO_CHAR(date_ymd, 'YYYY-MM-DD') AS iso_date
FROM dates
ORDER BY date_ymd;

CREATE OR REPLACE VIEW gold.fact_sales AS
/*
    Fact Table: Sales
    Contains foreign surrogate keys referencing gold dimensions.
    Accepts NULL dates when order status != 'delivered'.
    total = price + freight_value.
*/
WITH
-- Map customer surrogate keys
customers AS (
    SELECT customer_id, customer_key
    FROM gold.dim_customers
),
-- Map seller surrogate keys
sellers AS (
    SELECT seller_id, seller_key
    FROM gold.dim_sellers
),
-- Map product surrogate keys
products AS (
    SELECT product_id, product_key
    FROM gold.dim_products
),
-- Map status surrogate keys
status AS (
    SELECT status, status_key
    FROM gold.dim_status
),
-- Map date surrogate keys
calendar AS (
    SELECT date_ymd, date_key
    FROM gold.dim_calendar
)
SELECT
    ROW_NUMBER() OVER (ORDER BY oi.order_id, oi.order_item_id) AS order_key,

    -- Natural Keys
    oi.order_id,
    oi.order_item_id,

    -- Surrogate Keys (Foreign Keys)
    c.customer_key,
    s.seller_key,
    p.product_key,
    st.status_key,

    cal.date_key AS date_purchase_key,

    -- Measures
    oi.price,
    oi.freight_value,
    (oi.price + oi.freight_value) AS total

FROM silver.olist_order_items oi
JOIN silver.olist_orders o
    ON oi.order_id = o.order_id
LEFT JOIN customers c
    ON o.customer_id = c.customer_id
LEFT JOIN sellers s
    ON oi.seller_id = s.seller_id
LEFT JOIN products p
    ON oi.product_id = p.product_id
LEFT JOIN status st
    ON o.order_status = st.status
LEFT JOIN calendar cal
    ON o.order_purchase_timestamp::date = cal.date_ymd;