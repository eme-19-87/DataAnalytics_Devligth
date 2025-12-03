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
COMMENT ON COLUMN silver.olist_products.product_created_date IS 'Fecha en la cual se insertó este registro en la capa plata';



--Creación de la tabla para las ordenes derivada de bronze.olist_orders
-- Drop table if exists
DROP TABLE IF EXISTS silver.olist_orders;

-- Create orders table
CREATE TABLE silver.olist_orders (
    order_id VARCHAR(50),
    customer_id VARCHAR(50),
    order_status VARCHAR(50),
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,
    order_created_date TIMESTAMP DEFAULT CURRENT_DATE
);

-- Comentarios para documentación
COMMENT ON TABLE silver.olist_orders IS 'Este es el conjunto de datos central. Por cada orden se puede encontrar toda la otra información.';

COMMENT ON COLUMN silver.olist_orders.order_id IS 'Identificador único de la orden';

COMMENT ON COLUMN silver.olist_orders.customer_id IS 'Clave al conjunto de datos de los clientes. Cada orden tiene un único customer_id';

COMMENT ON COLUMN silver.olist_orders.order_status IS 'Referencia el estado de la orden (entregado, embarcado, etc.)';

COMMENT ON COLUMN silver.olist_orders.order_purchase_timestamp IS 'Muestra la fecha en que se compró';

COMMENT ON COLUMN silver.olist_orders.order_approved_at IS 'Muestra la fecha en que se aprobó la compra';

COMMENT ON COLUMN silver.olist_orders.order_delivered_carrier_date IS 'Muestra la fecha cuando fue manejado por la parte logística';

COMMENT ON COLUMN silver.olist_orders.order_delivered_customer_date IS 'Muestra la fecha en la cual la orden se le entregó al cliente';

COMMENT ON COLUMN silver.olist_orders.order_estimated_delivery_date IS 'Muestra la fecha estimada de entrega que se le informó al cliente en el momento de la compra';

COMMENT ON COLUMN silver.olist_orders.order_created_date IS 'La fecha en que se inserto este registro en la capa plata';




--Creación de la tabla para los items de las órdenes derivada de bronze.olist_order_items
-- Drop table if exists
DROP TABLE IF EXISTS silver.olist_order_items;

-- Create silver.order_items table
CREATE TABLE silver.olist_order_items (
    order_id VARCHAR(50) NOT NULL,
    order_item_id INTEGER NOT NULL,
    product_id VARCHAR(50) NOT NULL,
    seller_id VARCHAR(50) NOT NULL,
    shipping_limit_date TIMESTAMP NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    freight_value NUMERIC(10, 2) NOT NULL
);

-- Comentarios para documentación
COMMENT ON TABLE silver.olist_order_items IS 'Este conjunto de datos contiene los datos referidos a los items comprados dentro de cada orden. 
Por ejemplo, la orden cuyo order_id = 00143d0f86d6fbd9f9b38ab440ac16f5 tiene 3 items (el mismo producto). Cada item tiene el flete calculado de acuerdo a sus medidas y peso. Para obtener el total del flete para cada orden sólo debe sumarse:

El valor total para el producto es: 21.33 * 3 = 63.99
El total para el flete es: 15.10 * 3 = 45.30

El total de la orden (precio del producto + flete) : 45.30 + 63.99 = 109.29';

COMMENT ON COLUMN silver.olist_order_items.order_id IS 
'Identificador de orden único';

COMMENT ON COLUMN silver.olist_order_items.order_item_id IS 'Número secuencial que sirve como número de identificación del item incluido en la misma orden';

COMMENT ON COLUMN silver.olist_order_items.product_id IS 'Identificador único del producto';

COMMENT ON COLUMN silver.olist_order_items.seller_id IS 'Identificador único del vendedor';

COMMENT ON COLUMN silver.olist_order_items.shipping_limit_date IS 'Muestra la fecha límite de embarque que tiene el vendedor para manejar la orden a través de la parte logística.';

COMMENT ON COLUMN silver.olist_order_items.price IS 'El precio del item';

COMMENT ON COLUMN silver.olist_order_items.freight_value IS 'El valor del flete para ese item. Si una orden tiene más de un item, el precio del flete es dividido entre los items.';



--creación de la tabla silver.olist_order_payments
DROP TABLE IF EXISTS silver.olist_order_payments;

-- Create order_payments table
CREATE TABLE silver.olist_order_payments (
    order_id VARCHAR(50),
    payment_sequential INTEGER,
    payment_type VARCHAR(50),
    payment_installments INTEGER,
    payment_value NUMERIC(10, 2),
	payments_created_date TIMESTAMP DEFAULT CURRENT_DATE
);

-- Comentarios para documentación
COMMENT ON TABLE silver.olist_order_payments IS 'Este conjunto de datos contiene información sobre las opciones de pago para las ordenes.';

COMMENT ON COLUMN silver.olist_order_payments.order_id IS 'Identificador único de la orden';

COMMENT ON COLUMN silver.olist_order_payments.payment_sequential IS 'Un cliente puede pagar una orden con más de un método de pago. Si lo hace, una secuencia será creada.';

COMMENT ON COLUMN silver.olist_order_payments.payment_type IS 'Método de pago seleccionado por el cliente';

COMMENT ON COLUMN silver.olist_order_payments.payment_installments IS 'El número de cuotas elegidas por el cliente';

COMMENT ON COLUMN silver.olist_order_payments.payment_value IS 'El valor de la transacción';

COMMENT ON COLUMN silver.olist_order_payments.payments_created_date IS 'Fecha de cuando se insertó este registro en la capa plata';


--Creación de la tabla para las reseñas de las ordenes derivada de olist_order_reviews_dataset.csv
-- Drop table if exists
DROP TABLE IF EXISTS silver.olist_order_reviews;

-- Create order_reviews table
CREATE TABLE silver.olist_order_reviews (
    review_id VARCHAR(50),
    order_id VARCHAR(50),
    review_score INTEGER,
    review_comment_title TEXT,
    review_comment_message TEXT,
	review_creation_date TIMESTAMP,
	review_answer_timestamp TIMESTAMP,
	review_created_date TIMESTAMP DEFAULT CURRENT_DATE
);

-- Comentarios para documentación
COMMENT ON TABLE silver.olist_order_reviews IS 'Este conjunto de datos incluye los datos sobre las reseñas hechas por los clientes.';

COMMENT ON COLUMN silver.olist_order_reviews.review_id IS 'Identificador único de la reseña';

COMMENT ON COLUMN silver.olist_order_reviews.order_id IS 'Identificador único de la orden';

COMMENT ON COLUMN silver.olist_order_reviews.review_score IS 'Nota que va del 1 al 5, otorgada por el cliente en una encuesta de satisfacción';

COMMENT ON COLUMN silver.olist_order_reviews.review_comment_title IS 'Título del comentario de la reseña dejada por el cliente. En portugues';

COMMENT ON COLUMN silver.olist_order_reviews.review_comment_message IS 'Mensaje del comentario de la reseña dejado por el cliente. En portugues';

COMMENT ON COLUMN silver.olist_order_reviews.review_creation_date IS 'Muestra la fecha en la cual la encuesta de satisfacción fue enviada al cliente';

COMMENT ON COLUMN silver.olist_order_reviews.review_answer_timestamp IS 'Muestra el tiempo en responder la encuesta de satisfacción';

COMMENT ON COLUMN silver.olist_order_reviews.review_created_date IS 'Fecha de creación de cuándo se insertó este registro en la capa plata';

--creación de la tabla silver.olist_sellers

DROP TABLE IF EXISTS silver.olist_sellers;
-- Create sellers table
CREATE TABLE silver.olist_sellers (
    seller_id VARCHAR(50),
    seller_zip_code_prefix VARCHAR(10),
    seller_city VARCHAR(100),
    seller_state VARCHAR(2),
	seller_created_date TIMESTAMP DEFAULT CURRENT_DATE
);

-- Comentarios para documentación
COMMENT ON TABLE silver.olist_sellers IS 'Seller information including geographic location details';

COMMENT ON COLUMN silver.olist_sellers.seller_id IS 'Unique identifier for each seller, 32-character hash';

COMMENT ON COLUMN silver.olist_sellers.seller_zip_code_prefix IS 'First digits of Brazilian zip code where seller is located';

COMMENT ON COLUMN silver.olist_sellers.seller_city IS 'City where the seller is based';

COMMENT ON COLUMN silver.olist_sellers.seller_state IS 'Brazilian state where the seller is located (SP, RJ, MG, etc.)';

COMMENT ON COLUMN silver.olist_sellers.seller_created_date IS 'Fecha de creación de cuándo se insertó este registro en la capa plata';


/*creación de la tabla silver.olist_customers*/

-- Elimina la tabla si ya existe
DROP TABLE IF EXISTS silver.olist_customers;

-- Crea la tabla bronze.olist_customers derivada de olist_customers_dataset.csv
CREATE TABLE silver.olist_customers (
    customer_id VARCHAR(50),
    customer_unique_id VARCHAR(50),
    customer_zip_code_prefix VARCHAR(30),
    customer_city VARCHAR(100),
    customer_state VARCHAR(2),
	customer_created_date TIMESTAMP DEFAULT CURRENT_DATE
	
);

-- Comentarios para documentación de la tabla de clientes
COMMENT ON TABLE silver.olist_customers IS 'Este conjunto de datos contiene la información sobre los clientes y sus localizaciones. Se emplea para identificar clientes únicos en el conjunto de datos olist_orders_dataset para encontrar la localización para la entrega de las órdenes.
El sistema asigna a cada orden un único customer_id. Esto significa que el mismo cliente obtendrá diferentes ids para diferentes órdenes. El propósito de tener un customer_unique_id en el conjunto de datos es para permitir identificar clientes que han realizado “recompras” en la tienda.';

COMMENT ON COLUMN silver.olist_customers.customer_id IS 'Clave del conjunto de datos olist_orders_dataset. Cada orden tiene un único customer_id';

COMMENT ON COLUMN silver.olist_customers.customer_unique_id IS 'Identificador único del cliente';

COMMENT ON COLUMN silver.olist_customers.customer_zip_code_prefix IS 'Los primeros cinco dígitos del código zip del consumidor';
COMMENT ON COLUMN silver.olist_customers.customer_city IS 'Nombre de la ciudad del cliente';
COMMENT ON COLUMN silver.olist_customers.customer_state IS 'Estado del cliente';
COMMENT ON COLUMN silver.olist_customers.customer_created_date IS 'La fecha en la que se creo el registro';

--Creación de la tabla de geolocalización derivada de bronze.olist_geolocation
-- Drop table if exists
DROP TABLE IF EXISTS silver.olist_geolocation;

-- Create geolocation table
CREATE TABLE silver.olist_geolocation (
    geolocation_zip_code_prefix VARCHAR(30),
    geolocation_lat NUMERIC(20, 16),
    geolocation_lng NUMERIC(20, 16),
    geolocation_city VARCHAR(50),
    geolocation_state VARCHAR(2),
	geolocation_created_date TIMESTAMP DEFAULT CURRENT_DATE
);

-- Comentarios para documentación
COMMENT ON TABLE silver.olist_geolocation IS 'Este conjunto de datos contiene la información del código zip de Brazil y sus coordenadas de latitud y longitud. Se puede usar para dibujar mapas y para encontrar las distancias entre compradores y clientes.';

COMMENT ON COLUMN silver.olist_geolocation.geolocation_zip_code_prefix IS 
'Los primeros cinco dígitos del código zip.';

COMMENT ON COLUMN silver.olist_geolocation.geolocation_lat IS 'Latitud';

COMMENT ON COLUMN silver.olist_geolocation.geolocation_lng IS 'Longitud';

COMMENT ON COLUMN silver.olist_geolocation.geolocation_city IS 'Nombre de la ciudad';

COMMENT ON COLUMN silver.olist_geolocation.geolocation_state IS 'Nombre del estado';

COMMENT ON COLUMN silver.olist_geolocation.geolocation_created_date IS 'La fecha en la que se creo el registro';