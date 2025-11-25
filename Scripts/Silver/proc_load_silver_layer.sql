CREATE OR REPLACE PROCEDURE sp_load_products_silver_layer()
LANGUAGE plpgsql
AS $$
DECLARE
    t_start       TIMESTAMP;
    t_clean       TIMESTAMP;
    t_medians     TIMESTAMP;
    t_factors     TIMESTAMP;
    t_imputed     TIMESTAMP;
    t_insert      TIMESTAMP;
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
        WITH clean AS (
            SELECT
                product_id,
                COALESCE(NULLIF(TRIM(product_category_name), ''), 'n/a') AS product_category_name,
                product_name_lenght,
                product_description_lenght,
                product_photos_qty,
                product_weight_g::numeric AS product_weight_g,
                product_length_cm::numeric AS product_length_cm,
                product_height_cm::numeric AS product_height_cm,
                product_width_cm::numeric AS product_width_cm
            FROM bronze.olist_products
        ),

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

        agg AS (
            SELECT
                product_category_name,
                SUM(volume * weight) AS sum_xy,
                SUM(volume * volume) AS sum_x2
            FROM data_valid
            GROUP BY product_category_name
        ),

        factors AS (
            SELECT
                product_category_name,
                (sum_xy / NULLIF(sum_x2, 0)) AS optimal_factor
            FROM agg
        ),

        imputed AS (
            SELECT
                c.product_id,
                c.product_category_name,
                c.product_name_lenght,
                c.product_description_lenght,
                c.product_photos_qty,

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
