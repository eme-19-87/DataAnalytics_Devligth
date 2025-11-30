/*Controles para la tabla productos en la capa silver*/

--controla que los id de producto no sean nulos o que estén repetidos
select count(product_id) from silver.olist_products group by product_id
having count(product_id)>1 or product_id is null;

--controla si peso, altura, alto o ancho son nulos
select product_id,product_weight_g,product_length_cm,product_height_cm,product_width_cm,
product_category_name
from silver.olist_products 
where  
(product_weight_g is null) or  (product_length_cm is null) or (product_height_cm is null)
or  (product_width_cm is null);

--controla si peso, altura, alto o ancho tienen un valor menor o igual a 0
select product_id,product_weight_g,product_length_cm,product_height_cm,product_width_cm,
product_category_name
from silver.olist_products 
where  
(product_weight_g<=0) or  (product_length_cm<=0) or (product_height_cm<=0)
or (product_width_cm<=0);

--controla si la longitud del nombre del producto, la longitud de la descripción
--la cantidad de fotos del producto, son nulos
select product_id, product_name_lenght,product_description_lenght,product_photos_qty
from silver.olist_products 
where  
(product_name_lenght IS NULL) or (product_description_lenght IS NULL) or (product_photos_qty IS NULL);


select product_id, product_name_lenght,product_description_lenght,product_photos_qty
from silver.olist_products 
where  
(product_name_lenght<=0) or (product_description_lenght<0) or (product_photos_qty<0);


/*Controles para la tabla orders en la capa silver. La mayoría de los controles se centran
en las ordenes con estado delivered. */

--controla si hay nulos para los id de ordenes o de clientes
select * from bronze.olist_orders where order_id is null or customer_id is null;

--controla que no haya id de ordenes repetidas
select order_id,count(order_id) from bronze.olist_orders group by order_id
having count(order_id)>1;

--controla que no haya fechas de adquisición de productos superiores al tiempo de aprovación
select order_id from bronze.olist_orders where order_purchase_timestamp>order_approved_at
where order_status='delivered';

--controla que no haya fechas de adquisición de productos superiores a la fecha de entrega al delivery
select * from bronze.olist_orders where order_purchase_timestamp>order_delivered_carrier_date
where order_status='delivered';

--controla que no haya fechas de adquisición de productos superiores a la fecha de entrega al
--cliente
select order_id from bronze.olist_orders where order_purchase_timestamp>order_delivered_customer_date
where order_status='delivered';

--controla que no haya fechas de aprovación superiores a la fecha de entrega de la orden a la
--empresa encargada del delivery
select * from bronze.olist_orders where order_approved_at>order_delivered_carrier_date
where order_status='delivered';

--controla que no haya fechas de aprovación superiores a la fecha de entrega de la orden
--al cliente
select * from bronze.olist_orders where order_approved_at>order_delivered_customer_date
where order_status='delivered';

--controla que la fecha de entrega de la orden a la empresa que se encarga del delivery
--no sea superior que la fecha en la cual se entrega la orden al cliente.
select * from bronze.olist_orders where order_delivered_carrier_date>order_delivered_customer_date
where order_status='delivered';

select order_purchase_timestamp from bronze.olist_orders where order_purchase_timestamp is null
where order_status='delivered';
select order_approved_at from bronze.olist_orders where order_approved_at is null
where order_status='delivered';
select order_delivered_carrier_date from bronze.olist_orders where order_delivered_carrier_date is null
where order_status='delivered';
select order_delivered_customer_date from bronze.olist_orders where order_delivered_customer_date is null
where order_status='delivered';
select order_estimated_delivery_date from bronze.olist_orders where order_estimated_delivery_date is null
where order_status='delivered';


/*control para la tabla silver.order_items_control*/

--control de nulos
select order_id from bronze.olist_order_items where order_id is null;
select order_item_id from bronze.olist_order_items where order_item_id is null;
select product_id from bronze.olist_order_items where product_id is null;
select seller_id from bronze.olist_order_items where seller_id is null;
select shipping_limit_date from bronze.olist_order_items where shipping_limit_date is null;
select price from bronze.olist_order_items where price is null;
select freight_value from bronze.olist_order_items where freight_value is null;

--controla que el precio sea menor o igual a cero, y el flete menor a cero
select order_id from bronze.olist_order_items where price<=0;
select * from bronze.olist_order_items where freight_value<0;


/*control para silver.olist_order_payments*/

--controla nulos

select * from bronze.olist_order_payments where order_id is null;
select * from bronze.olist_order_payments where payment_sequential is null;
select * from bronze.olist_order_payments where payment_type is null;
select * from bronze.olist_order_payments where payment_installments is null;
select * from bronze.olist_order_payments where payment_value is null;


--control de valores menores a cero
--hay valores cero debido a son vouchers
select * from bronze.olist_order_payments where payment_value<=0;

--incosistencia entre el precio de venta y el precio de flete, con el precio de pago para
-- la orden cuyo order_id=0e556f5eafbf3eb399290101b183b10e
--Esto puede explicarse porque el campo payment_installments es el número de cuotas del pago
--y payment_sequential es el número de cuotas que ya pagó.
--Así que puede ser una situación en la cual todavía no se completaron los pagos cuando se 
--tomó la base de datos para analizarla.


/*control para la tabla silver.olist_order_reviews*/

--control de nulos
select * from bronze.olist_order_reviews where review_id is null;
select * from bronze.olist_order_reviews where order_id is null;
select * from bronze.olist_order_reviews where review_score is null;
select * from bronze.olist_order_reviews where review_creation_date is null;
select * from bronze.olist_order_reviews where review_answer_timestamp is null;

--que la fecha de la creación de la review no sea mayor a la fecha de respuesta
select * from bronze.olist_order_reviews where review_creation_date>review_answer_timestamp;

--que la puntuación no sea menor o igual a 0.
select * from bronze.olist_order_reviews where review_score<=0;

--controla que las columnas de cadena de caracteres no tengan espacio en blanco
select * from bronze.olist_order_reviews where TRIM(review_comment_title)!=review_comment_title;
select * from bronze.olist_order_reviews where TRIM(review_comment_message)!=review_comment_message;

