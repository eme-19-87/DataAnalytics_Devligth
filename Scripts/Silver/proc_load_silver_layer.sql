CREACREATE OR REPLACE PROCEDURE sp_load_products_silver_layer()
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


CREATE OR REPLACE PROCEDURE sp_load_orderss_silver_layer()
LANGUAGE plpgsql
AS $$
BEGIN
    TRUNCATE TABLE silver.olist_orders;
    INSERT INTO silver.olist_orders(
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
        o.order_id,
        o.customer_id,
        o.order_status,
        o.order_purchase_timestamp,

        -----------------------------------------
        -- 1) Corrección de order_approved_at
        -----------------------------------------
        CASE
            WHEN o.order_approved_at IS NULL 
                 AND o.order_status = 'delivered'
            THEN o.order_purchase_timestamp + INTERVAL '1 day'
            ELSE o.order_approved_at
        END AS order_approved_at_fixed,

        -----------------------------------------
        -- 2) Corrección de order_delivered_carrier_date
        -----------------------------------------
        CASE
            WHEN (o.order_purchase_timestamp > o.order_delivered_carrier_date 
                  OR o.order_delivered_carrier_date IS NULL)
                 AND o.order_status = 'delivered'
            THEN 
                -- usa el campo aprobado corregido
                COALESCE(o.order_approved_at,
                         o.order_purchase_timestamp + INTERVAL '1 day')
                + INTERVAL '1 day'
            ELSE o.order_delivered_carrier_date
        END AS carrier_fixed,

        -----------------------------------------
        -- 3) Corrección de order_delivered_customer_date
        -----------------------------------------
        CASE
            WHEN (o.order_purchase_timestamp > o.order_delivered_customer_date
                  OR o.order_delivered_customer_date IS NULL)
                 AND o.order_status = 'delivered'
            THEN 
                COALESCE(o.order_delivered_carrier_date,
                         o.order_approved_at,
                         o.order_purchase_timestamp + INTERVAL '1 day')
                + INTERVAL '1 day'
            ELSE o.order_delivered_customer_date
        END AS customer_fixed,

        o.order_estimated_delivery_date
    FROM bronze.olist_orders o;

END;
$$;

CREATE OR REPLACE PROCEDURE sp_load_order_items_silver_layer()
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



CREATE OR REPLACE PROCEDURE sp_master_load_silver_layer()
LANGUAGE plpgsql
AS $$
DECLARE
    t_total_start   TIMESTAMP;
    t_total_end     TIMESTAMP;

    t_products_start TIMESTAMP;
    t_products_end   TIMESTAMP;

    t_orders_start   TIMESTAMP;
    t_orders_end     TIMESTAMP;
BEGIN
    RAISE NOTICE '=== INICIO DEL PROCESO MAESTRO PARA CARGAR SILVER LAYERS ===';
    t_total_start := clock_timestamp();

    ----------------------------------------------------------------------
    -- TRY–CATCH 1: Cargar productos (silver.olist_products)
    ----------------------------------------------------------------------
    BEGIN
        RAISE NOTICE '>> Ejecutando sp_load_products_silver_layer() ...';
        t_products_start := clock_timestamp();

        CALL sp_load_products_silver_layer();

        t_products_end := clock_timestamp();
        RAISE NOTICE '   ✓ Finalizado sp_load_products_silver_layer() (% ms)',
            EXTRACT(MILLISECOND FROM t_products_end - t_products_start);

    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'ERROR dentro de sp_load_products_silver_layer(): %', SQLERRM;
    END;


    ----------------------------------------------------------------------
    -- TRY–CATCH 2: Cargar órdenes (silver.olist_orders)
    ----------------------------------------------------------------------
    BEGIN
        RAISE NOTICE '>> Ejecutando sp_load_orderss_silver_layer() ...';
        t_orders_start := clock_timestamp();

        CALL sp_load_orderss_silver_layer();

        t_orders_end := clock_timestamp();
        RAISE NOTICE '   ✓ Finalizado sp_load_orderss_silver_layer() (% ms)',
            EXTRACT(MILLISECOND FROM t_orders_end - t_orders_start);

    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'ERROR dentro de sp_load_orderss_silver_layer(): %', SQLERRM;
    END;

	----------------------------------------------------------------------
    -- 3) load order items   << NUEVO
    ----------------------------------------------------------------------
    BEGIN
        RAISE NOTICE '>> Ejecutando sp_load_order_items_silver_layer() ...';
        t_items_start := clock_timestamp();

        CALL sp_load_order_items_silver_layer();

        t_items_end := clock_timestamp();
        RAISE NOTICE '   ✓ Finalizado sp_load_order_items_silver_layer() (% ms)',
            EXTRACT(MILLISECOND FROM t_items_end - t_items_start);

    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION 'ERROR dentro de sp_load_order_items_silver_layer(): %', SQLERRM;
    END;


    ----------------------------------------------------------------------
    -- REPORTE FINAL
    ----------------------------------------------------------------------
    t_total_end := clock_timestamp();

    RAISE NOTICE '=== RESUMEN DE TIEMPOS DEL PROCESO MAESTRO ===';
    RAISE NOTICE 'Tiempo en productos:  % ms', EXTRACT(MILLISECOND FROM t_products_end - t_products_start);
    RAISE NOTICE 'Tiempo en órdenes:    % ms', EXTRACT(MILLISECOND FROM t_orders_end - t_orders_start);
    RAISE NOTICE 'TIEMPO TOTAL:         % ms', EXTRACT(MILLISECOND FROM t_total_end - t_total_start);
    RAISE NOTICE '=== FIN DEL PROCESO MAESTRO ===';

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'ERROR GENERAL EN SP_MASTER_LOAD_SILVER_LAYER(): %', SQLERRM;

END;
$$;

