/*Controles para la tabla productos en la capa silver*/

--controla la cantidad de registros presentes en la capa plata
--En el csv original, hay 32951 registros. Debería dar esa cantidad tb en la capa bronze
--Resultado de la prueba: OK
select count(*) from silver.olist_products;
select count(*) from bronze.olist_products;

--controla que los id de producto no sean nulos o que estén repetidos
--Resultado de la prueba: OK
select count(product_id) from silver.olist_products group by product_id
having count(product_id)>1 or product_id is null;

--controla si peso, altura, alto o ancho son nulos
--Resultado de la prueba: OK
select product_id,product_weight_g,product_length_cm,product_height_cm,product_width_cm,
product_category_name
from silver.olist_products 
where  
(product_weight_g is null) or  (product_length_cm is null) or (product_height_cm is null)
or  (product_width_cm is null);

--controla si peso, altura, alto o ancho tienen un valor menor o igual a 0
--Resultado de la prueba: OK
select product_id,product_weight_g,product_length_cm,product_height_cm,product_width_cm,
product_category_name
from silver.olist_products 
where  
(product_weight_g<=0) or  (product_length_cm<=0) or (product_height_cm<=0)
or (product_width_cm<=0);

--controla si la longitud del nombre del producto, la longitud de la descripción
--la cantidad de fotos del producto, no son nulos
--Resultado de la prueba: OK
select product_id, product_name_lenght,product_description_lenght,product_photos_qty
from silver.olist_products 
where  
(product_name_lenght IS NULL) or (product_description_lenght IS NULL) or (product_photos_qty IS NULL);

--Comprueba si la cantidad de caractres para el nombre es cero, descripción es menor a cero o el número 
--de fotos subidas es menor a cero.
--Resultado de la prueba: Hay registros que cumplen una o más condiciones. Es esperable.
--Estos resutados los tomamos como válidos porque no son campos con los que pretendemos trabajar.
select product_id, product_name_lenght,product_description_lenght,product_photos_qty
from silver.olist_products 
where  
(product_name_lenght<=0) or (product_description_lenght<0) or (product_photos_qty<0);


/*Controles para la tabla orders en la capa silver. La mayoría de los controles se centran
en las ordenes con estado delivered. */

--controla el númer de registros de la tabla. La cantidad de registros originales es de 99441
--Resultado de la prueba: OK

select count(*) from silver.olist_orders;
select count(*) from bronze.olist_orders;

--controla si hay nulos para los id de ordenes o de clientes
--Resultado de la prueba: OK
select * from silver.olist_orders where order_id is null or customer_id is null;

--controla que no haya id de ordenes repetidas
--Resultado de la prueba: OK
select order_id,count(order_id) from silver.olist_orders group by order_id
having count(order_id)>1;

--controla que no haya fechas de adquisición de productos superiores al tiempo de aprovación
--nos centramos en las ordenes en estado 'delivered'.
--Resultado de la prueba: OK

select order_id from silver.olist_orders where order_purchase_timestamp>order_approved_at
and order_status='delivered';

--controla que no haya fechas de adquisición de productos superiores a la fecha de entrega al delivery
--Resultado de la prueba: OK

select order_id from silver.olist_orders where order_purchase_timestamp>order_delivered_carrier_date
and order_status='delivered';

--controla que no haya fechas de adquisición de productos superiores a la fecha de entrega al
--cliente
--Resultado de la prueba: OK

select order_id from silver.olist_orders where order_purchase_timestamp>order_delivered_customer_date
and order_status='delivered';

--controla que no haya fechas de aprovación superiores a la fecha de entrega de la orden a la
--empresa encargada del delivery
--Resultado de la prueba: OK

select order_id from silver.olist_orders where order_approved_at>order_delivered_carrier_date
and order_status='delivered';

--controla que no haya fechas de aprovación superiores a la fecha de entrega de la orden
--al cliente
--Resultado de la prueba: OK

select order_id from silver.olist_orders where order_approved_at>order_delivered_customer_date and order_status='delivered';

--controla que la fecha de entrega de la orden a la empresa que se encarga del delivery
--no sea superior que la fecha en la cual se entrega la orden al cliente.
--Resultado de la prueba: OK

select order_id from silver.olist_orders where order_delivered_carrier_date>order_delivered_customer_date and order_status='delivered';

--control de nulos para las fechas de las ordenes con estado 'delivered'
--Resultado de las pruebas: OK
select order_purchase_timestamp from silver.olist_orders where order_purchase_timestamp is null
and order_status='delivered';
select order_approved_at from silver.olist_orders where order_approved_at is null
and order_status='delivered';
select order_delivered_carrier_date from silver.olist_orders where order_delivered_carrier_date is null
and order_status='delivered';
select order_delivered_customer_date from silver.olist_orders where order_delivered_customer_date is null and order_status='delivered';
select order_estimated_delivery_date from silver.olist_orders where order_estimated_delivery_date is null and order_status='delivered';


/*control para la tabla silver.olist_order_items*/

--control de cantidad de registros 112650
--Resultado de la prueba: OK

select count(*) from silver.olist_order_items;
select count(*) from bronze.olist_order_items;

--control de nulos
--Resultado de la prueba: OK
SELECT
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN order_item_id IS NULL THEN 1 ELSE 0 END) AS null_order_item_id,
    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_product_id,
    SUM(CASE WHEN seller_id IS NULL THEN 1 ELSE 0 END) AS null_seller_id,
    SUM(CASE WHEN shipping_limit_date IS NULL THEN 1 ELSE 0 END) AS null_shipping_limit_date,
    SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END) AS null_price,
    SUM(CASE WHEN freight_value IS NULL THEN 1 ELSE 0 END) AS null_freight_value
FROM silver.olist_order_items;

--controla que el precio no sea menor o igual a cero, y el flete no sea menor a cero
--Resultado de la prueba: OK
select order_id from silver.olist_order_items where price<=0;
select order_id from silver.olist_order_items where freight_value<0;




/*control para silver.olist_order_payments*/

--controla la cantidad de registros. Total: 103886
--Resultado de la prueba: OK

select count(*) from silver.olist_order_payments;
select count(*) from bronze.olist_order_payments;

--controla nulos
--Resultado de la prueba: OK
select order_id from silver.olist_order_payments where order_id is null;
select order_id from silver.olist_order_payments where payment_sequential is null;
select order_id from silver.olist_order_payments where payment_type is null;
select order_id from silver.olist_order_payments where payment_installments is null;
select order_id from silver.olist_order_payments where payment_value is null;


--control de valores menores a cero
--hay valores cero debido a son vouchers
--Resultado de la prueba: OK
select * from silver.olist_order_payments where payment_value<=0;

--control de valores menores a cero
--para valores que no sean voucher o not_defined
--Resultado de la prueba: OK
select * from silver.olist_order_payments
where payment_value<=0 and payment_type not in ('voucher','not_defined');

--incosistencia entre el precio de venta y el precio de flete, con el precio de pago para
-- la orden cuyo order_id=0e556f5eafbf3eb399290101b183b10e
--Esto puede explicarse porque el campo payment_installments es el número de cuotas del pago
--y payment_sequential es el número de cuotas que ya pagó.
--Así que puede ser una situación en la cual todavía no se completaron los pagos cuando se 
--tomó la base de datos para analizarla.


/*control para la tabla silver.olist_order_reviews*/

--control de la cantidad de registros. Total: 99224
--Resultado de la prueba: OK

select count(*) from silver.olist_order_reviews;
select count(*) from bronze.olist_order_reviews;

--control de nulos
--Resultado de la prueba: OK
select review_id from silver.olist_order_reviews where review_id is null;
select review_id from silver.olist_order_reviews where order_id is null;
select review from silver.olist_order_reviews where review_score is null;
select review_id from silver.olist_order_reviews where review_creation_date is null;
select review_id from silver.olist_order_reviews where review_answer_timestamp is null;

--que la fecha de la creación de la review no sea mayor a la fecha de respuesta
--Resultado de la prueba: OK
select review_id from silver.olist_order_reviews where review_creation_date>review_answer_timestamp;

--que la puntuación no sea menor o igual a 0.
--Resultado de la prueba: OK

select review_id from silver.olist_order_reviews where review_score<=0;

--controla que las columnas de cadena de caracteres no tengan espacio en blanco
--Resultado de la prueba: OK
select review_id from silver.olist_order_reviews where TRIM(review_comment_title)!=review_comment_title;
select review_id from silver.olist_order_reviews where TRIM(review_comment_message)!=review_comment_message;

/*control para la tabla silver.olist_sellers*/

--Total de registros. Total: 3095
--Resultado de la Prueba: OK
select count(*) from silver.olist_sellers

--revisa que no haya ciudades con nombres distintos a los que figuran en la tabla
--de geolocalización. Los zip_code_prefix coinciden, pero los nombres de ciudades
--difieren
select seller_city from silver.olist_sellers where seller_city not in(
select distinct geolocation_city from bronze.olist_geolocation
);

--control de los nulos
select * from silver.olist_sellers where seller_zip_code_prefix is null;
select * from silver.olist_sellers where seller_id is null;
select * from silver.olist_sellers where seller_city is null;
select * from silver.olist_sellers where seller_state is null;

/*control para la tabla silver.olist_customers*/

--control de nulos
select * from bronze.olist_customers where customer_id is null;
select * from bronze.olist_customers where customer_unique_id is null;
select * from bronze.olist_customers where customer_zip_code_prefix is null;
select * from bronze.olist_customers where customer_city is null;
select * from bronze.olist_customers where customer_state is null;

--controla los zip_code que están en clientes, pero no en geolocalización
--No se tendrá información de geolocalización para esto clientes.
select distinct customer_zip_code_prefix from bronze.olist_customers 
where customer_zip_code_prefix not in (
select distinct geolocation_zip_code_prefix from bronze.olist_geolocation
)

--controla los zip_code de ciudades que están en clientes, pero no en geolocalización.
--Esto es útil porque pueden haber ciudades con nombres distintos, pero mediante el zip_code
--podemos saber sus valores reales utilizando la tabla de geolocalización.
select distinct customer_zip_code_prefix from (
select customer_zip_code_prefix from bronze.olist_customers where customer_city not in(
select distinct geolocation_city from bronze.olist_geolocation
)) where customer_zip_code_prefix in (select distinct geolocation_zip_code_prefix from bronze.olist_geolocation)


/*control de la tabla de traducción portugués-inglés*/

select count(*) from bronze.olist_product_category_name_translation;
select count(*) from bronze.olist_product_category_name_translation where product_category_name is null ;
select count(*) from bronze.olist_product_category_name_translation 
where product_category_name_english is null ;

select count(*) from bronze.olist_product_category_name_translation 
where product_category_name!=TRIM(product_category_name);

select count(*) from bronze.olist_product_category_name_translation 
where product_category_name_english!=TRIM(product_category_name_english);


