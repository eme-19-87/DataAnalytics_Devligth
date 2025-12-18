/*
Script that allows data to be inserted into the silver layer. The Truncate-Insert method is applied. Therefore, running this script will remove the tables from the silver layer and rebuild them
Execute script and then write 

silver.sp_master_load_silver_layer()

To run the load
*/

CREATE OR REPLACE PROCEDURE silver.sp_load_products_silver_layer()
LANGUAGE plpgsql
AS $$
DECLARE
	--mide el tiempo inicial
    t_start       TIMESTAMP;
	--mide el tiempo que tarda en quitar los espacios en blanco
    t_clean       TIMESTAMP;
	--mide el tiempo que tarda en calcular las medianas
    t_medians     TIMESTAMP;
	--mide el tiempo que tarda en calcular los factores en caso de tener que aproximar el peso
    t_factors     TIMESTAMP;
	--tiempo que tarda que tarda en imputar los datos
    t_imputed     TIMESTAMP;
	--tiempo que tarda en insertar en la tabla de productos en la capa plata
    t_insert      TIMESTAMP;
	--el tiempo en que terminó todo
    t_end         TIMESTAMP;

BEGIN
    RAISE NOTICE '=== Inicio del procedimiento de limpieza de productos ===';
    t_start := clock_timestamp();

    ----------------------------------------------------------------------
    -- TRY–CATCH 0: Limpiar tabla destino
    ----------------------------------------------------------------------
    BEGIN
        RAISE NOTICE 'Vaciando tabla silver.olist_products...';
        TRUNCATE TABLE silver.olist_products;
        RAISE NOTICE 'Tabla vaciada.';
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Error al limpiar la tabla silver.olist_products: %', SQLERRM;
    END;

    ----------------------------------------------------------------------
    -- TRY–CATCH 1: Limpieza base
    ----------------------------------------------------------------------
    BEGIN
        RAISE NOTICE 'Iniciando limpieza de datos (categorías, nulos)...';
        t_clean := clock_timestamp();
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Error durante la etapa de limpieza base: %', SQLERRM;
    END;

    ----------------------------------------------------------------------
    -- TRY–CATCH 2: Cálculo de medianas
    ----------------------------------------------------------------------
    BEGIN
        RAISE NOTICE 'Calculando medianas por categoría...';
        t_medians := clock_timestamp();
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Error durante cálculo de medianas: %', SQLERRM;
    END;

    ----------------------------------------------------------------------
    -- TRY–CATCH 3: Cálculo de factores
    ----------------------------------------------------------------------
    BEGIN
        RAISE NOTICE 'Calculando factores óptimos por categoría...';
        t_factors := clock_timestamp();
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Error durante el cálculo de factores óptimos: %', SQLERRM;
    END;

    ----------------------------------------------------------------------
    -- TRY–CATCH 4: Imputación
    ----------------------------------------------------------------------
    BEGIN
        RAISE NOTICE 'Realizando imputación de dimensiones y peso...';
        t_imputed := clock_timestamp();
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Error durante el proceso de imputación: %', SQLERRM;
    END;

    ----------------------------------------------------------------------
    -- TRY–CATCH 5: Inserción final
    ----------------------------------------------------------------------
    BEGIN
        RAISE NOTICE 'Insertando datos limpios en silver.olist_products...';
        t_insert := clock_timestamp();

        ------------------------------------------------------------------
        -- PROCESAMIENTO REAL
        ------------------------------------------------------------------

		------------------------------------------------------------------
        -- clean tendrá los valores del product_category_name='n/a' si es nulo
		--Si product_name_lenght, product_description_lenght, product_photos_qty
		--es nulo, entonces se colocará el valor a 0
        ------------------------------------------------------------------
        WITH clean AS (
            SELECT
                product_id,
                COALESCE(NULLIF(TRIM(product_category_name), ''), 'n/a') AS product_category_name,
                COALESCE(product_name_lenght,0) As product_name_lenght,
                COALESCE(product_description_lenght,0) AS product_description_lenght,
                COALESCE(product_photos_qty,0) AS product_photos_qty,
                product_weight_g::numeric AS product_weight_g,
                product_length_cm::numeric AS product_length_cm,
                product_height_cm::numeric AS product_height_cm,
                product_width_cm::numeric AS product_width_cm
            FROM bronze.olist_products
        ),
		------------------------------------------------------------------
        -- medianas calcula las medianas agrupándolos por categorías
		--solo los calcula para registros donde peso, altura, ancho y peso 
		--no son nulos
        ------------------------------------------------------------------
        medianas AS (
            SELECT 
                product_category_name,
                percentile_cont(0.5) WITHIN GROUP (ORDER BY product_weight_g)   AS median_weight,
                percentile_cont(0.5) WITHIN GROUP (ORDER BY product_length_cm)  AS median_length,
                percentile_cont(0.5) WITHIN GROUP (ORDER BY product_height_cm)  AS median_height,
                percentile_cont(0.5) WITHIN GROUP (ORDER BY product_width_cm)   AS median_width
            FROM clean
            WHERE product_weight_g IS NOT NULL
              AND product_length_cm IS NOT NULL
              AND product_height_cm IS NOT NULL
              AND product_width_cm IS NOT NULL
            GROUP BY product_category_name
        ),
		------------------------------------------------------------------
        -- data_valid permite calcular el volumen de cada producto, sólo si
		--el peso no es nulo, y peso, altura, ancho y alto sean mayores a cero
        ------------------------------------------------------------------
        data_valid AS (
            SELECT
                product_category_name,
                product_weight_g AS weight,
                (product_length_cm * product_height_cm * product_width_cm) AS volume
            FROM clean
            WHERE product_weight_g IS NOT NULL 
              AND product_weight_g > 0
              AND product_length_cm > 0
              AND product_height_cm > 0
              AND product_width_cm > 0
        ),

		------------------------------------------------------------------
        -- en agg para cada categoria agrupada se suman volumen*weigth
		--y se suman el cuadrado del volumen
        ------------------------------------------------------------------
        agg AS (
            SELECT
                product_category_name,
                SUM(volume * weight) AS sum_xy,
                SUM(volume * volume) AS sum_x2
            FROM data_valid
            GROUP BY product_category_name
        ),
		------------------------------------------------------------------
        -- en factors, se calcula el factor=suma(volumen*peso)/suma(volumen*volumen)
        ------------------------------------------------------------------
        factors AS (
            SELECT
                product_category_name,
                (sum_xy / NULLIF(sum_x2, 0)) AS optimal_factor
            FROM agg
        ),
		------------------------------------------------------------------
        -- imputed, aplicamos las imputaciones
        ------------------------------------------------------------------
        imputed AS (
            SELECT
                c.product_id,
                c.product_category_name,
                c.product_name_lenght,
                c.product_description_lenght,
                c.product_photos_qty,
				--Si el alto, largo, ancho es nulo, se reemplaza por la mediana
                COALESCE(NULLIF(c.product_length_cm,  0), m.median_length)  AS imputed_length,
                COALESCE(NULLIF(c.product_height_cm, 0), m.median_height)  AS imputed_height,
                COALESCE(NULLIF(c.product_width_cm,  0), m.median_width)   AS imputed_width,

                (COALESCE(NULLIF(c.product_length_cm,  0), m.median_length) *
                 COALESCE(NULLIF(c.product_height_cm, 0), m.median_height) *
                 COALESCE(NULLIF(c.product_width_cm,  0), m.median_width)) AS final_volume,

                f.optimal_factor,

                CASE
                    WHEN c.product_weight_g IS NULL
                      OR c.product_weight_g <= 0
                    THEN f.optimal_factor *
                         (COALESCE(NULLIF(c.product_length_cm,  0), m.median_length) *
                          COALESCE(NULLIF(c.product_height_cm, 0), m.median_height) *
                          COALESCE(NULLIF(c.product_width_cm,  0), m.median_width))
                    ELSE c.product_weight_g
                END AS final_weight

            FROM clean c
            LEFT JOIN medianas m ON c.product_category_name = m.product_category_name
            LEFT JOIN factors  f ON c.product_category_name = f.product_category_name
        )

        INSERT INTO silver.olist_products(
            product_id, product_category_name, product_name_lenght, 
            product_description_lenght, product_photos_qty,
            product_length_cm, product_height_cm, product_width_cm, product_weight_g
        )
        SELECT
            product_id,
            product_category_name,
            product_name_lenght,
            product_description_lenght,
            product_photos_qty,
            imputed_length,
            imputed_height,
            imputed_width,
            ROUND(final_weight::NUMERIC, 0)
        FROM imputed
        ORDER BY product_category_name, product_id;

    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'Error durante la inserción final en silver.olist_products: %', SQLERRM;
    END;

    ----------------------------------------------------------------------
    -- REPORTE FINAL
    ----------------------------------------------------------------------
    t_end := clock_timestamp();

    RAISE NOTICE '--- TIEMPOS ---';
    RAISE NOTICE 'Limpieza base:       % ms', EXTRACT(MILLISECOND FROM t_medians - t_clean);
    RAISE NOTICE 'Cálculo medianas:    % ms', EXTRACT(MILLISECOND FROM t_factors - t_medians);
    RAISE NOTICE 'Cálculo factores:    % ms', EXTRACT(MILLISECOND FROM t_imputed - t_factors);
    RAISE NOTICE 'Imputación:          % ms', EXTRACT(MILLISECOND FROM t_insert - t_imputed);
    RAISE NOTICE 'Inserción:           % ms', EXTRACT(MILLISECOND FROM t_end - t_insert);
    RAISE NOTICE 'Tiempo TOTAL:        % ms', EXTRACT(MILLISECOND FROM t_end - t_start);

    RAISE NOTICE '=== Fin del procedimiento ===';

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error general en sp_clean_products: %', SQLERRM;

END;
$$;


CREATE OR REPLACE PROCEDURE silver.sp_load_orders_silver_layer()
LANGUAGE plpgsql
AS $$
DECLARE
    -- tiempos
    t_start        TIMESTAMP;
    t_after_trunc  TIMESTAMP;
    t_after_insert TIMESTAMP;

    -- medianas (intervalos)
    med_purchase_to_approved INTERVAL;
    med_approved_to_carrier  INTERVAL;
    med_carrier_to_customer  INTERVAL;
BEGIN
    t_start := clock_timestamp();
    RAISE NOTICE 'Inicio procedimiento: %', t_start;

    BEGIN
        ---------------------------------------------------------------------
        -- 1. CALCULAR MEDIANAS (solo relaciones válidas)
        ---------------------------------------------------------------------
        SELECT
            percentile_cont(0.5) WITHIN GROUP (
                ORDER BY order_approved_at - order_purchase_timestamp
            ),
            percentile_cont(0.5) WITHIN GROUP (
                ORDER BY order_delivered_carrier_date - order_approved_at
            ),
            percentile_cont(0.5) WITHIN GROUP (
                ORDER BY order_delivered_customer_date - order_delivered_carrier_date
            )
        INTO
            med_purchase_to_approved,
            med_approved_to_carrier,
            med_carrier_to_customer
        FROM bronze.olist_orders
        WHERE order_status = 'delivered'
          AND order_purchase_timestamp IS NOT NULL
          AND order_approved_at IS NOT NULL
          AND order_delivered_carrier_date IS NOT NULL
          AND order_delivered_customer_date IS NOT NULL
          AND order_purchase_timestamp < order_approved_at
          AND order_approved_at < order_delivered_carrier_date
          AND order_delivered_carrier_date < order_delivered_customer_date;

        RAISE NOTICE 'Medianas calculadas:';
        RAISE NOTICE ' purchase → approved : %', med_purchase_to_approved;
        RAISE NOTICE ' approved → carrier  : %', med_approved_to_carrier;
        RAISE NOTICE ' carrier → customer  : %', med_carrier_to_customer;

        ---------------------------------------------------------------------
        -- 2. TRUNCATE
        ---------------------------------------------------------------------
        TRUNCATE TABLE silver.olist_orders;
        t_after_trunc := clock_timestamp();

        RAISE NOTICE 'Tiempo TRUNCATE: % segundos',
            EXTRACT(EPOCH FROM (t_after_trunc - t_start));

        ---------------------------------------------------------------------
        -- 3. INSERT con imputación encadenada (sin tocar estimated)
        ---------------------------------------------------------------------
        WITH approved AS (
            SELECT
                o.*,
                CASE
                    WHEN o.order_approved_at IS NULL
                      OR o.order_approved_at <= o.order_purchase_timestamp
                    THEN o.order_purchase_timestamp + med_purchase_to_approved
                    ELSE o.order_approved_at
                END AS approved_fixed
            FROM bronze.olist_orders o
        ),
        carrier AS (
            SELECT
                *,
                CASE
                    WHEN order_delivered_carrier_date IS NULL
                      OR order_delivered_carrier_date <= approved_fixed
                    THEN approved_fixed + med_approved_to_carrier
                    ELSE order_delivered_carrier_date
                END AS carrier_fixed
            FROM approved
        ),
        customer AS (
            SELECT
                *,
                CASE
                    WHEN order_delivered_customer_date IS NULL
                      OR order_delivered_customer_date <= carrier_fixed
                    THEN carrier_fixed + med_carrier_to_customer
                    ELSE order_delivered_customer_date
                END AS customer_fixed
            FROM carrier
        )
        INSERT INTO silver.olist_orders (
            order_id,
            customer_id,
            order_status,
            order_purchase_timestamp,
            order_approved_at,
            order_delivered_carrier_date,
            order_delivered_customer_date,
            order_estimated_delivery_date
        )
        SELECT
            order_id,
            customer_id,
            order_status,
            order_purchase_timestamp,
            approved_fixed,
            carrier_fixed,
            customer_fixed,
            -- estimated se mantiene tal cual
            order_estimated_delivery_date
        FROM customer;

        t_after_insert := clock_timestamp();

        RAISE NOTICE 'Tiempo INSERT: % segundos',
            EXTRACT(EPOCH FROM (t_after_insert - t_after_trunc));

        RAISE NOTICE 'Tiempo TOTAL procedimiento: % segundos',
            EXTRACT(EPOCH FROM (t_after_insert - t_start));

    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION
            'Error en sp_load_orders_silver_layer(): %', SQLERRM;
    END;
END;
$$;



CREATE OR REPLACE PROCEDURE silver.sp_load_order_items_silver_layer()
LANGUAGE plpgsql
AS $$
BEGIN
    TRUNCATE TABLE silver.olist_order_items;
    RAISE NOTICE 'Insertando registros en silver.olist_order_items...';

    INSERT INTO silver.olist_order_items(
        order_id,
        order_item_id,
        product_id,
        seller_id,
        shipping_limit_date,
        price,
        freight_value
    )
    SELECT
        order_id,
        order_item_id,
        product_id,
        seller_id,
        shipping_limit_date,
        price,
        freight_value
    FROM bronze.olist_order_items;

    RAISE NOTICE 'Inserción en olist_order_items finalizada.';

END;
$$;

CREATE OR REPLACE PROCEDURE silver.sp_load_payments_silver_layer()
LANGUAGE plpgsql
AS $$
DECLARE
    t_start        TIMESTAMP;
    t_truncate_end TIMESTAMP;
    t_insert_end   TIMESTAMP;
    t_end          TIMESTAMP;

BEGIN
    ------------------------------------------------------------------
    -- Inicio del proceso
    ------------------------------------------------------------------
    t_start := clock_timestamp();
    RAISE NOTICE 'Inicio total: %', t_start;

    ------------------------------------------------------------------
    -- TRUNCATE
    ------------------------------------------------------------------
    BEGIN
        TRUNCATE TABLE silver.olist_order_payments RESTART IDENTITY;
        t_truncate_end := clock_timestamp();
        RAISE NOTICE 'Tiempo TRUNCATE: % segundos',
            EXTRACT(EPOCH FROM (t_truncate_end - t_start));
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Error en TRUNCATE: %', SQLERRM;
            RETURN;
    END;

    ------------------------------------------------------------------
    -- INSERT
    ------------------------------------------------------------------
    BEGIN
        INSERT INTO silver.olist_order_payments(
            order_id,
            payment_sequential,
            payment_type,
            payment_installments,
            payment_value
        )
        SELECT 
            order_id,
            payment_sequential,
            payment_type,
            payment_installments,
            payment_value
        FROM bronze.olist_order_payments;

        t_insert_end := clock_timestamp();
        RAISE NOTICE 'Tiempo INSERT: % segundos',
            EXTRACT(EPOCH FROM (t_insert_end - t_truncate_end));
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Error en INSERT: %', SQLERRM;
            RETURN;
    END;

    ------------------------------------------------------------------
    -- Tiempo total
    ------------------------------------------------------------------
    t_end := clock_timestamp();
    RAISE NOTICE 'Tiempo TOTAL: % segundos',
        EXTRACT(EPOCH FROM (t_end - t_start));

END;
$$;


CREATE OR REPLACE PROCEDURE silver.sp_load_sellers_silver_layer()
LANGUAGE plpgsql
AS $$
DECLARE
    t_start           TIMESTAMP;
    t_truncate_start  TIMESTAMP;
    t_insert_start    TIMESTAMP;
    t_end             TIMESTAMP;

    dur_truncate      INTERVAL;
    dur_insert        INTERVAL;
    dur_total         INTERVAL;
BEGIN
    ---------------------------------------------------------------------
    -- Inicio medición total
    ---------------------------------------------------------------------
    t_start := clock_timestamp();

    ---------------------------------------------------------------------
    -- TRUNCATE + medición
    ---------------------------------------------------------------------
    t_truncate_start := clock_timestamp();

    TRUNCATE TABLE silver.olist_sellers;

    dur_truncate := clock_timestamp() - t_truncate_start;

    RAISE NOTICE 'Tiempo TRUNCATE: %', dur_truncate;

    ---------------------------------------------------------------------
    -- INSERT + medición
    ---------------------------------------------------------------------
    t_insert_start := clock_timestamp();

    
    WITH cleaned AS (
        SELECT 
            seller_id,
            seller_zip_code_prefix,
            ss.brazil_state as "seller_state_abbr",
            ss.brazil_state_name as "seller_state",
            -- Optimizamos: convertimos una sola vez a lower
            LOWER(TRIM(seller_city)) AS city_lower,
            TRIM(seller_city) AS original_city
        FROM bronze.olist_sellers s
        INNER JOIN bronze.blog_mds_gov_br_brazil_state_list ss
        ON s.seller_state=ss.brazil_state
    ),
    transformed AS (
        SELECT
            seller_id,
            seller_zip_code_prefix,
            CASE
                WHEN city_lower = 'brejao' THEN 'brejão'
                WHEN city_lower IN ('vendas@creditparts.com.br') THEN 'maringa'
                WHEN city_lower IN ('andira-pr') THEN 'barra do jacare'
                WHEN city_lower IN ('belo horizont') THEN 'belo horizonte'
                WHEN city_lower IN ('portoferreira') THEN 'porto ferreira'
                WHEN city_lower IN ('paiçandu','paincandu') THEN 'brejão'
                WHEN city_lower IN ('bahia') THEN 'paulo afonso'
                WHEN city_lower IN ('santa catarina') THEN 'palhoca'
                WHEN city_lower IN ('sao  jose dos pinhais','sao jose dos pinhas') THEN 'sao jose dos pinhais'
                WHEN city_lower IN ('vicente de carvalho') THEN 'guaruja'
                WHEN city_lower IN ('ferraz de  vasconcelos') THEN 'ferraz de vasconcelos'
                WHEN city_lower IN ('lages - sc') THEN 'lages'
                WHEN city_lower IN ('balenario camboriu') THEN 'balneario camboriu'
                WHEN city_lower IN ('auriflama/sp') THEN 'auriflama'
                WHEN city_lower IN ('sao paulo / sao paulo','sao paulo sp','sao paluo',
                                    'sao paulop','sao paulo - sp','sao pauo',
                                    'sp / sp','sao  paulo','são paulo') THEN 'são paulo'
                WHEN city_lower = 'cascavael' THEN 'cascavel'
                WHEN city_lower IN ('santa barbara d´oeste','santa barbara d oeste') THEN 'santa barbara d''oeste'
                WHEN city_lower = 'novo hamburgo, rio grande do sul, brasil' THEN 'novo hamburgo'
                WHEN city_lower = 'floranopolis' THEN 'florianopolis'
                WHEN city_lower = 'cariacica / es' THEN 'cariacica'
                WHEN city_lower IN ('sao miguel do oeste','sao miguel d''oeste') THEN 'sao miguel do oeste'
                WHEN city_lower IN ('brasilia df','aguas claras df') THEN 'brasilia'
                WHEN city_lower IN ('mogi das cruses','mogi das cruzes / sp') THEN 'mogi das cruzes'
                WHEN city_lower IN ('sbc/sp','sbc','sao bernardo do capo',
                                    'maua/sao paulo','ao bernardo do campo',
                                    'sao bernardo do campo') THEN 'sao bernardo do campo'
                WHEN city_lower = 'arraial d''ajuda (porto seguro)' THEN 'arraial d''ajuda'
                WHEN city_lower IN ('santo andre/sao paulo','sando andre') THEN 'santo andre'
                WHEN city_lower IN ('s jose do rio preto','sao jose do rio pret') THEN 'sao jose do rio preto'
                WHEN city_lower = 'juzeiro do norte' THEN 'juazeiro do norte'
                WHEN city_lower IN ('rio de janeiro \\rio de janeiro','rio de janeiro \rio de janeiro',
                                    'rio de janeiro / rio de janeiro','04482255') THEN 'rio de janeiro'
                WHEN city_lower = 'angra dos reis rj' THEN 'angra dos reis'
                WHEN city_lower = 'pinhais/pr' THEN 'pinhais'
                WHEN city_lower = 'castro pires' THEN 'teofilo otoni'
                WHEN city_lower = 'garulhos' THEN 'guarulhos'
                WHEN city_lower IN ('ribeirao preto / sao paulo','robeirao preto',
                                    'ribeirao pretp','riberao preto') THEN 'ribeirao preto'
                WHEN city_lower = 'ji parana' THEN 'ji-parana'
                WHEN city_lower = 'carapicuiba / sao paulo' THEN 'carapicuiba'
                WHEN city_lower = 'centro' THEN 'para de minas'
                WHEN city_lower = 'minas gerais' THEN 'campo do meio'
                WHEN city_lower = 'scao jose do rio pardo' THEN 'sao jose do rio pardo'
                WHEN city_lower = 'tabao da serra' THEN 'taboao da serra'
                WHEN city_lower = 'jacarei / sao paulo' THEN 'jacarei'
                WHEN city_lower = 'barbacena/ minas gerais' THEN 'barbacena'
                WHEN city_lower = 'sao sebastiao da grama/sp' THEN 'sao sebastiao da grama'
                ELSE original_city
            END AS "seller_city",
			seller_state,
            seller_state_abbr
        FROM cleaned
    )
	INSERT INTO silver.olist_sellers(seller_id, seller_zip_code_prefix, seller_city, seller_state,seller_state_abbr)
    SELECT * FROM transformed;

    dur_insert := clock_timestamp() - t_insert_start;

    RAISE NOTICE 'Tiempo INSERT: %', dur_insert;

    ---------------------------------------------------------------------
    -- Fin total
    ---------------------------------------------------------------------
    t_end := clock_timestamp();
    dur_total := t_end - t_start;

    RAISE NOTICE 'Tiempo TOTAL del procedimiento: %', dur_total;

EXCEPTION
    WHEN OTHERS THEN
        RAISE WARNING 'Error en sp_load_silver_olist_sellers: %', SQLERRM;
        RAISE;
END;
$$;


CREATE OR REPLACE PROCEDURE silver.sp_load_order_reviews_silver_layer()
LANGUAGE plpgsql
AS $$
DECLARE
    t_start TIMESTAMP;
    t_end   TIMESTAMP;

    median_review_score NUMERIC;
BEGIN
    RAISE NOTICE '=== INICIO: sp_load_order_reviews_silver_layer() ===';
    t_start := clock_timestamp();

    BEGIN
        ----------------------------------------------------------------------
        -- CALCULAR MEDIANA DE review_score CON percentile_cont
        ----------------------------------------------------------------------
        SELECT
            percentile_cont(0.5)
            WITHIN GROUP (ORDER BY review_score)
        INTO median_review_score
        FROM bronze.olist_order_reviews
        WHERE review_score IS NOT NULL;

        RAISE NOTICE '>> Mediana calculada de review_score = %', median_review_score;

        ----------------------------------------------------------------------
        -- TRUNCATE
        ----------------------------------------------------------------------
        RAISE NOTICE '>> TRUNCATE TABLE silver.olist_order_reviews ...';
        TRUNCATE TABLE silver.olist_order_reviews;

        ----------------------------------------------------------------------
        -- INSERT CON IMPUTACIÓN POR MEDIANA
        ----------------------------------------------------------------------
        RAISE NOTICE '>> INSERTANDO registros en silver.olist_order_reviews ...';

        INSERT INTO silver.olist_order_reviews (
            review_id,
            order_id,
            review_score,
            review_comment_title,
            review_comment_message,
            review_creation_date,
            review_answer_timestamp
        )
        SELECT
            review_id,
            order_id,
            COALESCE(review_score, median_review_score)      AS review_score,
            TRIM(COALESCE(review_comment_title, 'n/a'))     AS review_comment_title,
            TRIM(COALESCE(review_comment_message, 'n/a'))   AS review_comment_message,
            review_creation_date,
            review_answer_timestamp
        FROM bronze.olist_order_reviews;

        RAISE NOTICE '✓ Inserción completada correctamente.';

    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION
            'ERROR dentro de sp_load_order_reviews_silver_layer(): %',
            SQLERRM;
    END;

    ----------------------------------------------------------------------
    -- TIEMPO TOTAL
    ----------------------------------------------------------------------
    t_end := clock_timestamp();
    RAISE NOTICE '=== FIN: sp_load_order_reviews_silver_layer() ===';
    RAISE NOTICE 'Tiempo total: % ms',
        EXTRACT(MILLISECOND FROM (t_end - t_start));

END;
$$;


CREATE OR REPLACE PROCEDURE silver.sp_load_customers_silver_layer()
LANGUAGE plpgsql
AS $$
DECLARE
    v_start_total      TIMESTAMP;
    v_end_total        TIMESTAMP;
    v_start_truncate   TIMESTAMP;
    v_end_truncate     TIMESTAMP;
    v_start_insert     TIMESTAMP;
    v_end_insert       TIMESTAMP;
BEGIN
    -- Tiempo inicio total
    v_start_total := clock_timestamp();

    BEGIN
        --------------------------------------------------------------------
        -- TRUNCATE TABLE
        --------------------------------------------------------------------
        v_start_truncate := clock_timestamp();

        TRUNCATE TABLE silver.olist_customers RESTART IDENTITY;

        v_end_truncate := clock_timestamp();

        --------------------------------------------------------------------
        -- INSERT DATA
        --------------------------------------------------------------------
        v_start_insert := clock_timestamp();

        INSERT INTO silver.olist_customers(
            customer_id,
            customer_unique_id,
            customer_zip_code_prefix,
            customer_city,
            customer_state,
            customer_state_abbr
        )
        SELECT 
            customer_id,
            customer_unique_id,
            customer_zip_code_prefix,

            CASE
                WHEN LOWER(customer_city) IN ('nucleo residencial pilar') THEN TRIM('jaguarari')
                WHEN LOWER(customer_city) IN ('mussurepe') THEN TRIM('campos dos goytacazes')
                WHEN LOWER(customer_city) IN ('caldas do jorro') THEN TRIM('tucano')
                WHEN LOWER(customer_city) IN ('taboquinhas') THEN TRIM('itacare')
                WHEN LOWER(customer_city) IN ('piacu') THEN TRIM('muniz freire')
                WHEN LOWER(customer_city) IN ('ajapi') THEN TRIM('rio claro')
                WHEN LOWER(customer_city) IN ('guariroba') THEN TRIM('taquaritinga')
                WHEN LOWER(customer_city) IN ('colonia jordaozinho') THEN TRIM('vitoria')
                ELSE TRIM(customer_city)
            END AS customer_city,
            TRIM(ss.brazil_state_name) as "customer_state",
            TRIM(ss.brazil_state) as "customer_state_abbr"
        FROM bronze.olist_customers c
        INNER JOIN bronze.blog_mds_gov_br_brazil_state_list ss 
        ON c.customer_state=ss.brazil_state;

        v_end_insert := clock_timestamp();

    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Error ejecutando sp_load_olist_customers(): %', SQLERRM;
    END;

    -- Tiempo fin total
    v_end_total := clock_timestamp();

    ------------------------------------------------------------------------
    -- LOG DE TIEMPOS
    ------------------------------------------------------------------------
    RAISE NOTICE 'Tiempo TRUNCATE: % segundos', EXTRACT(EPOCH FROM (v_end_truncate - v_start_truncate));
    RAISE NOTICE 'Tiempo INSERT: % segundos',   EXTRACT(EPOCH FROM (v_end_insert - v_start_insert));
    RAISE NOTICE 'Tiempo TOTAL: % segundos',    EXTRACT(EPOCH FROM (v_end_total - v_start_total));

END;
$$;

CREATE OR REPLACE PROCEDURE silver.sp_load_geolocation_silver_layer()
LANGUAGE plpgsql
AS $$
DECLARE
    v_start_total      TIMESTAMP;
    v_end_total        TIMESTAMP;
    v_start_truncate   TIMESTAMP;
    v_end_truncate     TIMESTAMP;
    v_start_insert     TIMESTAMP;
    v_end_insert       TIMESTAMP;
BEGIN
    -- Inicio del tiempo total
    v_start_total := clock_timestamp();

    BEGIN
        --------------------------------------------------------------------
        -- TRUNCATE TABLE
        --------------------------------------------------------------------
        v_start_truncate := clock_timestamp();

        TRUNCATE TABLE silver.olist_geolocation RESTART IDENTITY;

        v_end_truncate := clock_timestamp();

        --------------------------------------------------------------------
        -- INSERT DATA WITH AGGREGATION
        --------------------------------------------------------------------
        v_start_insert := clock_timestamp();

        INSERT INTO silver.olist_geolocation (
            geolocation_zip_code_prefix,
            geolocation_lat,
            geolocation_lng,
            geolocation_city,
            geolocation_state
        )
        SELECT
            geolocation_zip_code_prefix,
            AVG(geolocation_lat)  AS avg_latitude,
            AVG(geolocation_lng)  AS avg_longitude,
            MIN(geolocation_city) AS city,
            MIN(geolocation_state) AS state
        FROM bronze.olist_geolocation 
        GROUP BY geolocation_zip_code_prefix
        ORDER BY geolocation_zip_code_prefix;

        v_end_insert := clock_timestamp();

    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Error ejecutando silver.sp_load_geolocation_silver_layer(): %', SQLERRM;
    END;

    -- Fin del tiempo total
    v_end_total := clock_timestamp();

    ------------------------------------------------------------------------
    -- LOG DE TIEMPOS
    ------------------------------------------------------------------------
    RAISE NOTICE 'Tiempo TRUNCATE: % segundos', EXTRACT(EPOCH FROM (v_end_truncate - v_start_truncate));
    RAISE NOTICE 'Tiempo INSERT: % segundos',   EXTRACT(EPOCH FROM (v_end_insert - v_start_insert));
    RAISE NOTICE 'Tiempo TOTAL: % segundos',    EXTRACT(EPOCH FROM (v_end_total - v_start_total));

END;
$$;


CREATE OR REPLACE PROCEDURE silver.sp_load_olist_category_translation_silver_layer()
LANGUAGE plpgsql
AS $$
DECLARE
    inicio_total        TIMESTAMP;
    inicio_truncate     TIMESTAMP;
    fin_truncate        TIMESTAMP;
    inicio_insert       TIMESTAMP;
    fin_insert          TIMESTAMP;
BEGIN
    -- Tiempo inicial del procedimiento
    inicio_total := clock_timestamp();

    BEGIN
        RAISE NOTICE '=== INICIO DEL PROCEDIMIENTO === %', inicio_total;

        -----------------------------------------------
        -- TRUNCATE (si no lo necesitas, elimínalo)
        -----------------------------------------------
        inicio_truncate := clock_timestamp();
        RAISE NOTICE 'Inicio TRUNCATE: %', inicio_truncate;

        TRUNCATE TABLE silver.olist_product_category_name_translation;

        fin_truncate := clock_timestamp();
        RAISE NOTICE 'Fin TRUNCATE: %', fin_truncate;
        RAISE NOTICE 'Tiempo TRUNCATE: % ms', EXTRACT(MILLISECOND FROM (fin_truncate - inicio_truncate));

        -----------------------------------------------
        -- INSERT
        -----------------------------------------------
        inicio_insert := clock_timestamp();
        RAISE NOTICE 'Inicio INSERT: %', inicio_insert;

        INSERT INTO silver.olist_product_category_name_translation (
            product_category_name,
            product_category_name_english
        )
        SELECT 
            product_category_name,
            product_category_name_english
        FROM bronze.olist_product_category_name_translation;

        fin_insert := clock_timestamp();
        RAISE NOTICE 'Fin INSERT: %', fin_insert;
        RAISE NOTICE 'Tiempo INSERT: % ms', EXTRACT(MILLISECOND FROM (fin_insert - inicio_insert));

        -----------------------------------------------
        -- Fin total
        -----------------------------------------------
        RAISE NOTICE '=== FIN DEL PROCEDIMIENTO === %', clock_timestamp();
        RAISE NOTICE 'Tiempo TOTAL del procedimiento: % ms',
            EXTRACT(MILLISECOND FROM (clock_timestamp() - inicio_total));

    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'ERROR: %', SQLERRM;
        RAISE NOTICE 'El procedimiento falló en el tiempo: %', clock_timestamp();
        RAISE;
    END;
END;
$$;



CREATE OR REPLACE PROCEDURE silver.sp_master_load_silver_layer()
LANGUAGE plpgsql
AS $$
DECLARE
    -- Tiempos globales
    t_total_start   TIMESTAMP;
    t_total_end     TIMESTAMP;

    -- Tiempos productos
    t_products_start TIMESTAMP;
    t_products_end   TIMESTAMP;

    -- Tiempos órdenes
    t_orders_start   TIMESTAMP;
    t_orders_end     TIMESTAMP;

    -- Tiempos order_items
    t_items_start TIMESTAMP;
    t_items_end   TIMESTAMP;

    -- Tiempos order_payments
    t_payments_start TIMESTAMP;
    t_payments_end   TIMESTAMP;

    -- Tiempos order_reviews  << NUEVO
    t_reviews_start TIMESTAMP;
    t_reviews_end   TIMESTAMP;

	--tiempo para los vendedores
	t_sellers_start TIMESTAMP;
    t_sellers_end   TIMESTAMP;

	--tiempo para los clientes
	t_customers_start TIMESTAMP;
    t_customers_end   TIMESTAMP;

	--tiempo para la geolocalización
	t_geo_start TIMESTAMP;
    t_geo_end   TIMESTAMP;

	--tiempo para la traducción de las categorías
	t_trans_start TIMESTAMP;
    t_trans_end   TIMESTAMP;
BEGIN
    RAISE NOTICE '=== INICIO DEL PROCESO MAESTRO PARA CARGAR SILVER LAYERS ===';
    t_total_start := clock_timestamp();


    ----------------------------------------------------------------------
    -- 1) Productos
    ----------------------------------------------------------------------
    BEGIN
        RAISE NOTICE '>> Ejecutando sp_load_products_silver_layer() ...';
        t_products_start := clock_timestamp();

        CALL silver.sp_load_products_silver_layer();

        t_products_end := clock_timestamp();
        RAISE NOTICE '   ✓ Finalizado sp_load_products_silver_layer() (% ms)',
            EXTRACT(MILLISECOND FROM t_products_end - t_products_start);

    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'ERROR dentro de sp_load_products_silver_layer(): %', SQLERRM;
    END;


    ----------------------------------------------------------------------
    -- 2) Órdenes
    ----------------------------------------------------------------------
    BEGIN
        RAISE NOTICE '>> Ejecutando sp_load_orderss_silver_layer() ...';
        t_orders_start := clock_timestamp();

        CALL silver.sp_load_orderss_silver_layer();

        t_orders_end := clock_timestamp();
        RAISE NOTICE '   ✓ Finalizado sp_load_orderss_silver_layer() (% ms)',
            EXTRACT(MILLISECOND FROM t_orders_end - t_orders_start);

    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'ERROR dentro de sp_load_orderss_silver_layer(): %', SQLERRM;
    END;


    ----------------------------------------------------------------------
    -- 3) Order Items
    ----------------------------------------------------------------------
    BEGIN
        RAISE NOTICE '>> Ejecutando sp_load_order_items_silver_layer() ...';
        t_items_start := clock_timestamp();

        CALL silver.sp_load_order_items_silver_layer();

        t_items_end := clock_timestamp();
        RAISE NOTICE '   ✓ Finalizado sp_load_order_items_silver_layer() (% ms)',
            EXTRACT(MILLISECOND FROM t_items_end - t_items_start);

    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'ERROR dentro de sp_load_order_items_silver_layer(): %', SQLERRM;
    END;


    ----------------------------------------------------------------------
    -- 4) Order Payments
    ----------------------------------------------------------------------
    BEGIN
        RAISE NOTICE '>> Ejecutando sp_load_order_payments_silver_layer() ...';
        t_payments_start := clock_timestamp();

        CALL silver.sp_load_payments_silver_layer();

        t_payments_end := clock_timestamp();
        RAISE NOTICE '   ✓ Finalizado sp_load_order_payments_silver_layer() (% ms)',
            EXTRACT(MILLISECOND FROM t_payments_end - t_payments_start);

    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'ERROR dentro de sp_load_order_payments_silver_layer(): %', SQLERRM;
    END;


    ----------------------------------------------------------------------
    -- 5) Order Reviews
    ----------------------------------------------------------------------
    BEGIN
        RAISE NOTICE '>> Ejecutando sp_load_order_reviews_silver_layer() ...';
        t_reviews_start := clock_timestamp();

        CALL silver.sp_load_order_reviews_silver_layer();

        t_reviews_end := clock_timestamp();
        RAISE NOTICE '   ✓ Finalizado sp_load_order_reviews_silver_layer() (% ms)',
            EXTRACT(MILLISECOND FROM t_reviews_end - t_reviews_start);

    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'ERROR dentro de sp_load_order_reviews_silver_layer(): %', SQLERRM;
    END;

	 ----------------------------------------------------------------------
    -- 6) Sellers
    ----------------------------------------------------------------------
    BEGIN
        RAISE NOTICE '>> Ejecutando sp_load_sellers_silver_layer()...';
        t_sellers_start := clock_timestamp();

        CALL silver.sp_load_sellers_silver_layer();

        t_sellers_end := clock_timestamp();
        RAISE NOTICE '   ✓ Finalizado sp_load_sellers_silver_layer (% ms)',
            EXTRACT(MILLISECOND FROM t_sellers_end - t_sellers_start);

    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'ERROR dentro de sp_load_sellers_silver_layer(): %', SQLERRM;
    END;

	 ----------------------------------------------------------------------
    -- 7) Customers
    ----------------------------------------------------------------------
    BEGIN
        RAISE NOTICE '>> Ejecutando silver.sp_load_customers_silver_layer()...';
        t_customers_start := clock_timestamp();

        CALL silver.sp_load_customers_silver_layer();

        t_customers_end := clock_timestamp();
        RAISE NOTICE '   ✓ Finalizado silver.sp_load_customers_silver_layer()(% ms)',
            EXTRACT(MILLISECOND FROM t_customers_end - t_customers_start);

    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'ERROR dentro de silver.sp_load_customers_silver_layer(): %', SQLERRM;
    END;

	 ----------------------------------------------------------------------
    -- 8) Geolocation
    ----------------------------------------------------------------------
    BEGIN
        RAISE NOTICE '>> Ejecutando silver.sp_load_geolocation_silver_layer()...';
        t_geo_start := clock_timestamp();

        CALL silver.sp_load_geolocation_silver_layer();

        t_geo_end := clock_timestamp();
        RAISE NOTICE '   ✓ Finalizado silver.sp_load_geolocation_silver_layer()(% ms)',
            EXTRACT(MILLISECOND FROM t_geo_end - t_geo_start);

    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'ERROR dentro de silver.sp_load_geolocation_silver_layer(): %', SQLERRM;
    END;

	 ----------------------------------------------------------------------
    -- 9) Category Translation
    ----------------------------------------------------------------------
    BEGIN
        RAISE NOTICE '>> Ejecutando sp_load_olist_category_translation_silver_layer()()';
        t_trans_start := clock_timestamp();

        CALL silver.sp_load_olist_category_translation_silver_layer();

        t_trans_end := clock_timestamp();
        RAISE NOTICE '   ✓ Finalizado sp_load_olist_category_translation_silver_layer()(% ms)',
            EXTRACT(MILLISECOND FROM t_trans_end - t_trans_start);

    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'ERROR dentro de silver.sp_cargar_olist_category_translation_silver_layer(): %', SQLERRM;
    END;
    
	
    ----------------------------------------------------------------------
    -- RESUMEN FINAL
    ----------------------------------------------------------------------
    t_total_end := clock_timestamp();

    RAISE NOTICE '=== RESUMEN DE TIEMPOS DEL PROCESO MAESTRO ===';
    RAISE NOTICE 'Tiempo en productos:        % ms', EXTRACT(MILLISECOND FROM t_products_end - t_products_start);
    RAISE NOTICE 'Tiempo en órdenes:          % ms', EXTRACT(MILLISECOND FROM t_orders_end - t_orders_start);
    RAISE NOTICE 'Tiempo en order items:      % ms', EXTRACT(MILLISECOND FROM t_items_end - t_items_start);
    RAISE NOTICE 'Tiempo en payments:         % ms', EXTRACT(MILLISECOND FROM t_payments_end - t_payments_start);
    RAISE NOTICE 'Tiempo en reviews:          % ms', EXTRACT(MILLISECOND FROM t_reviews_end - t_reviews_start);
	RAISE NOTICE 'Tiempo en sellers:          % ms', EXTRACT(MILLISECOND FROM t_sellers_end - t_sellers_start);
	RAISE NOTICE 'Tiempo en customers:        % ms', EXTRACT(MILLISECOND FROM t_customers_end - t_customers_start);
	RAISE NOTICE 'Tiempo en geolocation:      % ms', EXTRACT(MILLISECOND FROM t_geo_end - t_geo_start);
	RAISE NOTICE 'Tiempo en traduccion:      % ms', EXTRACT(MILLISECOND FROM t_trans_end - t_trans_start);
    RAISE NOTICE '-----------------------------------------';
    RAISE NOTICE 'TIEMPO TOTAL:               % ms', EXTRACT(MILLISECOND FROM t_total_end - t_total_start);
    RAISE NOTICE '=== FIN DEL PROCESO MAESTRO ===';

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'ERROR GENERAL EN SP_MASTER_LOAD_SILVER_LAYER(): %', SQLERRM;

END;
$$;
