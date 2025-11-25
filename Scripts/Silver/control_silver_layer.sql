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

