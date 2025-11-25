/*
===============================================================================
DDL Script: Cración de las tablas de la capa silver
===============================================================================
Propósito Del Script: Este script se encarga de crear las tablas de la capa de
bronce. Las creará en el esquema 'silver'.
En caso de que existan, eliminarás las tablas primeramente.
Ejecutar este script redefine la estructuras de la tabla en el esquema 'silver'.
Las tablas de esta capa fueron:
-Limpiadas de nulos y datos inconsistentes en los capos.
-Normalizado y estandarizado.
-Se agregadon columnas accesorias para indicar su fecha de creación
===============================================================================
*/

--Crea el esquema en caso de que no exista
CREATE SCHEMA IF NOT EXISTS silver;

--Creación de la tabla de productos derivada de bronze.olist_products

-- Drop table if exists
DROP TABLE IF EXISTS silver.olist_products;

-- Create products table
CREATE TABLE silver.olist_products (
    product_id VARCHAR(50),
    product_category_name VARCHAR(100),
    product_name_lenght INTEGER,
    product_description_lenght INTEGER,
    product_photos_qty INTEGER,
    product_weight_g INTEGER,
    product_length_cm INTEGER,
    product_height_cm INTEGER,
    product_width_cm INTEGER,
    product_created_date TIMESTAMP DEFAULT CURRENT_DATE
);

-- Comentarios para documentación
COMMENT ON TABLE silver.olist_products IS 'Product catalog with detailed product information and dimensions';

COMMENT ON COLUMN silver.olist_products.product_id IS 'Unique identifier for each product, 32-character hash';

COMMENT ON COLUMN silver.olist_products.product_category_name IS 'Product category name in Portuguese (e.g., perfumaria, utilidades_domesticas)';

COMMENT ON COLUMN silver.olist_products.product_name_lenght IS 'Length of the product name in characters';

COMMENT ON COLUMN silver.olist_products.product_description_lenght IS 'Length of the product description in characters';

COMMENT ON COLUMN silver.olist_products.product_photos_qty IS 'Number of product photos available';

COMMENT ON COLUMN silver.olist_products.product_weight_g IS 'Product weight in grams';

COMMENT ON COLUMN silver.olist_products.product_length_cm IS 'Product length in centimeters';

COMMENT ON COLUMN silver.olist_products.product_height_cm IS 'Product height in centimeters';

COMMENT ON COLUMN silver.olist_products.product_width_cm IS 'Product width in centimeters';
COMMENT ON COLUMN silver.olist_products.product_created_date IS 'Product width in centimeters';