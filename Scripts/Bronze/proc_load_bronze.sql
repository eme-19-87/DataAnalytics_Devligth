/*
===============================================================================
Stored Procedure: sp_load_data(Source -> Bronze)
===============================================================================
Propósito del script:
	Este procedimiento almacenado carga en el esquema 'bronze' desde archivo CSV
	externos.
	Realiza las siguientes acciones:
	-Aplica TRUNCATE a las tablas en la capa 'bronze' que fueron cargadas previamente.
	-Mediante el comando COPY FROM carga los datos desde archivos CSV externos a las tablas
	en la capa 'bronze'.
  

Parametros:
    Ninguno. 

Retorno
	Ninguno

Ejemplo de uso:
    CALL bronze.sp_load_data();
===============================================================================
*/
CREATE OR REPLACE PROCEDURE bronze.sp_load_data()
LANGUAGE plpgsql
AS $$
DECLARE
    start_total TIMESTAMP;
    start_truncate TIMESTAMP;
    start_copy TIMESTAMP;
    end_copy TIMESTAMP;
    total_duration INTERVAL;
    truncate_duration INTERVAL;
    copy_duration INTERVAL;
    load_duration INTERVAL;
    record_count INTEGER;
BEGIN
    -- Inicio medición tiempo total
    start_total := clock_timestamp();
    RAISE NOTICE '🚀 INICIANDO CARGA DE DATOS - %', start_total;
    
    -- Bloque TRY-CATCH
    BEGIN
        -- Fase 1: TRUNCATE para olist_customers
        start_truncate := clock_timestamp();
        RAISE NOTICE '🗑️  Ejecutando TRUNCATE...';
        
        TRUNCATE TABLE bronze.olist_customers;
        
        truncate_duration := clock_timestamp() - start_truncate;
        RAISE NOTICE '✅ TRUNCATE completado en: %', truncate_duration;
        
        -- Fase 2: COPY para olist_customers
        start_copy := clock_timestamp();
        RAISE NOTICE '📥 Ejecutando COPY desde CSV...';
        
        COPY bronze.olist_customers FROM '/import_data/olist_customers_dataset.csv' 
        DELIMITER E',' 
        CSV HEADER;
        
        end_copy := clock_timestamp();
        copy_duration := end_copy - start_copy;
        
        
        -- Cálculos finales de tiempos para olist_customers
        total_duration := end_copy - start_total;
        load_duration := end_copy - start_truncate;  -- truncate + copy
        
        -- REPORTE FINAL
        RAISE NOTICE '========================================';
        RAISE NOTICE '🎉 CARGA COMPLETADA EXITOSAMENTE PARA para bronze.olist_customers';
        RAISE NOTICE '========================================';
        RAISE NOTICE '📊 ESTADÍSTICAS:';
        RAISE NOTICE '   Registros cargados: %', record_count;
        RAISE NOTICE '⏱️  TIEMPOS:';
        RAISE NOTICE '   • TRUNCATE: %', truncate_duration;
        RAISE NOTICE '   • COPY: %', copy_duration;
        RAISE NOTICE '   • CARGA TOTAL (truncate + copy): %', load_duration;
        RAISE NOTICE '   • TRANSACCIÓN COMPLETA: %', total_duration;
        RAISE NOTICE '========================================';

		 -- Fase 1: TRUNCATE para olist_geolocation
        start_truncate := clock_timestamp();
        RAISE NOTICE '🗑️  Ejecutando TRUNCATE...';
        
        TRUNCATE TABLE bronze.olist_geolocation;
        
        truncate_duration := clock_timestamp() - start_truncate;
        RAISE NOTICE '✅ TRUNCATE completado en: %', truncate_duration;
        
        -- Fase 2: COPY para olist_geolocation
        start_copy := clock_timestamp();
        RAISE NOTICE '📥 Ejecutando COPY desde CSV...';
        
        COPY bronze.olist_geolocation FROM '/import_data/olist_geolocation_dataset.csv' 
        DELIMITER E',' 
        CSV HEADER;
        
        end_copy := clock_timestamp();
        copy_duration := end_copy - start_copy;
        
        
        -- Cálculos finales de tiempos
        total_duration := end_copy - start_total;
        load_duration := end_copy - start_truncate;  -- truncate + copy
        
        -- REPORTE FINAL
        RAISE NOTICE '========================================';
        RAISE NOTICE '🎉 CARGA COMPLETADA EXITOSAMENTE para bronze.olist_geolocation';
        RAISE NOTICE '========================================';
        RAISE NOTICE '📊 ESTADÍSTICAS:';
        RAISE NOTICE '   Registros cargados: %', record_count;
        RAISE NOTICE '⏱️  TIEMPOS:';
        RAISE NOTICE '   • TRUNCATE: %', truncate_duration;
        RAISE NOTICE '   • COPY: %', copy_duration;
        RAISE NOTICE '   • CARGA TOTAL (truncate + copy): %', load_duration;
        RAISE NOTICE '   • TRANSACCIÓN COMPLETA: %', total_duration;
        RAISE NOTICE '========================================';

		 -- Fase 1: TRUNCATE para olist_order_items
        start_truncate := clock_timestamp();
        RAISE NOTICE '🗑️  Ejecutando TRUNCATE...';
        
        TRUNCATE TABLE bronze.olist_order_items;
        
        truncate_duration := clock_timestamp() - start_truncate;
        RAISE NOTICE '✅ TRUNCATE completado en: %', truncate_duration;
        
        -- Fase 2: COPY para olist_order_items
        start_copy := clock_timestamp();
        RAISE NOTICE '📥 Ejecutando COPY desde CSV...';
        
        COPY bronze.olist_order_items FROM '/import_data/olist_order_items_dataset.csv' 
        DELIMITER E',' 
        CSV HEADER;
        
        end_copy := clock_timestamp();
        copy_duration := end_copy - start_copy;
    
        
        -- Cálculos finales de tiempos
        total_duration := end_copy - start_total;
        load_duration := end_copy - start_truncate;  -- truncate + copy
        
        -- REPORTE FINAL
        RAISE NOTICE '========================================';
        RAISE NOTICE '🎉 CARGA COMPLETADA EXITOSAMENTE para bronze.olist_order_items';
        RAISE NOTICE '========================================';
        RAISE NOTICE '📊 ESTADÍSTICAS:';
        RAISE NOTICE '   Registros cargados: %', record_count;
        RAISE NOTICE '⏱️  TIEMPOS:';
        RAISE NOTICE '   • TRUNCATE: %', truncate_duration;
        RAISE NOTICE '   • COPY: %', copy_duration;
        RAISE NOTICE '   • CARGA TOTAL (truncate + copy): %', load_duration;
        RAISE NOTICE '   • TRANSACCIÓN COMPLETA: %', total_duration;
        RAISE NOTICE '========================================';

		-- Fase 1: TRUNCATE para olist_order_payments
        start_truncate := clock_timestamp();
        RAISE NOTICE '🗑️  Ejecutando TRUNCATE...';
        
        TRUNCATE TABLE bronze.olist_order_payments;
        
        truncate_duration := clock_timestamp() - start_truncate;
        RAISE NOTICE '✅ TRUNCATE completado en: %', truncate_duration;
        
        -- Fase 2: COPY para olist_order_items
        start_copy := clock_timestamp();
        RAISE NOTICE '📥 Ejecutando COPY desde CSV...';
        
        COPY bronze.olist_order_payments FROM '/import_data/olist_order_payments_dataset.csv' 
        DELIMITER E',' 
        CSV HEADER;
        
        end_copy := clock_timestamp();
        copy_duration := end_copy - start_copy;
    
        
        -- Cálculos finales de tiempos
        total_duration := end_copy - start_total;
        load_duration := end_copy - start_truncate;  -- truncate + copy
        
        -- REPORTE FINAL
        RAISE NOTICE '========================================';
        RAISE NOTICE '🎉 CARGA COMPLETADA EXITOSAMENTE para bronze.olist_order_payments';
        RAISE NOTICE '========================================';
        RAISE NOTICE '📊 ESTADÍSTICAS:';
        RAISE NOTICE '   Registros cargados: %', record_count;
        RAISE NOTICE '⏱️  TIEMPOS:';
        RAISE NOTICE '   • TRUNCATE: %', truncate_duration;
        RAISE NOTICE '   • COPY: %', copy_duration;
        RAISE NOTICE '   • CARGA TOTAL (truncate + copy): %', load_duration;
        RAISE NOTICE '   • TRANSACCIÓN COMPLETA: %', total_duration;
        RAISE NOTICE '========================================';

		-- Fase 1: TRUNCATE para olist_order_reviews
        start_truncate := clock_timestamp();
        RAISE NOTICE '🗑️  Ejecutando TRUNCATE...';
        
        TRUNCATE TABLE bronze.olist_order_reviews;
        
        truncate_duration := clock_timestamp() - start_truncate;
        RAISE NOTICE '✅ TRUNCATE completado en: %', truncate_duration;
        
        -- Fase 2: COPY para olist_order_items
        start_copy := clock_timestamp();
        RAISE NOTICE '📥 Ejecutando COPY desde CSV...';
        
        COPY bronze.olist_order_reviews FROM '/import_data/olist_order_reviews_dataset.csv' 
        DELIMITER E',' 
        CSV HEADER;
        
        end_copy := clock_timestamp();
        copy_duration := end_copy - start_copy;
    
        
        -- Cálculos finales de tiempos
        total_duration := end_copy - start_total;
        load_duration := end_copy - start_truncate;  -- truncate + copy
        
        -- REPORTE FINAL
        RAISE NOTICE '========================================';
        RAISE NOTICE '🎉 CARGA COMPLETADA EXITOSAMENTE para bronze.olist_order_reviews';
        RAISE NOTICE '========================================';
        RAISE NOTICE '📊 ESTADÍSTICAS:';
        RAISE NOTICE '   Registros cargados: %', record_count;
        RAISE NOTICE '⏱️  TIEMPOS:';
        RAISE NOTICE '   • TRUNCATE: %', truncate_duration;
        RAISE NOTICE '   • COPY: %', copy_duration;
        RAISE NOTICE '   • CARGA TOTAL (truncate + copy): %', load_duration;
        RAISE NOTICE '   • TRANSACCIÓN COMPLETA: %', total_duration;
        RAISE NOTICE '========================================';

		-- Fase 1: TRUNCATE para olist_orders
        start_truncate := clock_timestamp();
        RAISE NOTICE '🗑️  Ejecutando TRUNCATE...';
        
        TRUNCATE TABLE bronze.olist_orders;
        
        truncate_duration := clock_timestamp() - start_truncate;
        RAISE NOTICE '✅ TRUNCATE completado en: %', truncate_duration;
        
        -- Fase 2: COPY para olist_orders
        start_copy := clock_timestamp();
        RAISE NOTICE '📥 Ejecutando COPY desde CSV...';
        
        COPY bronze.olist_orders FROM '/import_data/olist_orders_dataset.csv' 
        DELIMITER E',' 
        CSV HEADER;
        
        end_copy := clock_timestamp();
        copy_duration := end_copy - start_copy;
    
        
        -- Cálculos finales de tiempos
        total_duration := end_copy - start_total;
        load_duration := end_copy - start_truncate;  -- truncate + copy
        
        -- REPORTE FINAL
        RAISE NOTICE '========================================';
        RAISE NOTICE '🎉 CARGA COMPLETADA EXITOSAMENTE para bronze.olist_orders';
        RAISE NOTICE '========================================';
        RAISE NOTICE '📊 ESTADÍSTICAS:';
        RAISE NOTICE '   Registros cargados: %', record_count;
        RAISE NOTICE '⏱️  TIEMPOS:';
        RAISE NOTICE '   • TRUNCATE: %', truncate_duration;
        RAISE NOTICE '   • COPY: %', copy_duration;
        RAISE NOTICE '   • CARGA TOTAL (truncate + copy): %', load_duration;
        RAISE NOTICE '   • TRANSACCIÓN COMPLETA: %', total_duration;
        RAISE NOTICE '========================================';

		-- Fase 1: TRUNCATE para olist_products
        start_truncate := clock_timestamp();
        RAISE NOTICE '🗑️  Ejecutando TRUNCATE...';
        
        TRUNCATE TABLE bronze.olist_products;
        
        truncate_duration := clock_timestamp() - start_truncate;
        RAISE NOTICE '✅ TRUNCATE completado en: %', truncate_duration;
        
        -- Fase 2: COPY para olist_orders
        start_copy := clock_timestamp();
        RAISE NOTICE '📥 Ejecutando COPY desde CSV...';
        
        COPY bronze.olist_products FROM '/import_data/olist_products_dataset.csv' 
        DELIMITER E',' 
        CSV HEADER;
        
        end_copy := clock_timestamp();
        copy_duration := end_copy - start_copy;
    
        
        -- Cálculos finales de tiempos
        total_duration := end_copy - start_total;
        load_duration := end_copy - start_truncate;  -- truncate + copy
        
        -- REPORTE FINAL
        RAISE NOTICE '========================================';
        RAISE NOTICE '🎉 CARGA COMPLETADA EXITOSAMENTE para bronze.olist_producst';
        RAISE NOTICE '========================================';
        RAISE NOTICE '📊 ESTADÍSTICAS:';
        RAISE NOTICE '   Registros cargados: %', record_count;
        RAISE NOTICE '⏱️  TIEMPOS:';
        RAISE NOTICE '   • TRUNCATE: %', truncate_duration;
        RAISE NOTICE '   • COPY: %', copy_duration;
        RAISE NOTICE '   • CARGA TOTAL (truncate + copy): %', load_duration;
        RAISE NOTICE '   • TRANSACCIÓN COMPLETA: %', total_duration;
        RAISE NOTICE '========================================';

		-- Fase 1: TRUNCATE para olist_sellers
        start_truncate := clock_timestamp();
        RAISE NOTICE '🗑️  Ejecutando TRUNCATE...';
        
        TRUNCATE TABLE bronze.olist_sellers;
        
        truncate_duration := clock_timestamp() - start_truncate;
        RAISE NOTICE '✅ TRUNCATE completado en: %', truncate_duration;
        
        -- Fase 2: COPY para olist_orders
        start_copy := clock_timestamp();
        RAISE NOTICE '📥 Ejecutando COPY desde CSV...';
        
        COPY bronze.olist_sellers FROM '/import_data/olist_sellers_dataset.csv' 
        DELIMITER E',' 
        CSV HEADER;
        
        end_copy := clock_timestamp();
        copy_duration := end_copy - start_copy;
    
        
        -- Cálculos finales de tiempos
        total_duration := end_copy - start_total;
        load_duration := end_copy - start_truncate;  -- truncate + copy
        
        -- REPORTE FINAL
        RAISE NOTICE '========================================';
        RAISE NOTICE '🎉 CARGA COMPLETADA EXITOSAMENTE para bronze.olist_sellers';
        RAISE NOTICE '========================================';
        RAISE NOTICE '📊 ESTADÍSTICAS:';
        RAISE NOTICE '   Registros cargados: %', record_count;
        RAISE NOTICE '⏱️  TIEMPOS:';
        RAISE NOTICE '   • TRUNCATE: %', truncate_duration;
        RAISE NOTICE '   • COPY: %', copy_duration;
        RAISE NOTICE '   • CARGA TOTAL (truncate + copy): %', load_duration;
        RAISE NOTICE '   • TRANSACCIÓN COMPLETA: %', total_duration;
        RAISE NOTICE '========================================';

		-- Fase 1: TRUNCATE para product_category_name_translation
        start_truncate := clock_timestamp();
        RAISE NOTICE '🗑️  Ejecutando TRUNCATE...';
        
        TRUNCATE TABLE bronze.olist_product_category_name_translation;
        
        truncate_duration := clock_timestamp() - start_truncate;
        RAISE NOTICE '✅ TRUNCATE completado en: %', truncate_duration;
        
        -- Fase 2: COPY para olist_orders
        start_copy := clock_timestamp();
        RAISE NOTICE '📥 Ejecutando COPY desde CSV...';
        
        COPY bronze.olist_product_category_name_translation FROM '/import_data/product_category_name_translation.csv' 
        DELIMITER E',' 
        CSV HEADER;
        
        end_copy := clock_timestamp();
        copy_duration := end_copy - start_copy;
    
        
        -- Cálculos finales de tiempos
        total_duration := end_copy - start_total;
        load_duration := end_copy - start_truncate;  -- truncate + copy
        
        -- REPORTE FINAL
        RAISE NOTICE '========================================';
        RAISE NOTICE '🎉 CARGA COMPLETADA EXITOSAMENTE para bronze.olist_product_category_name_translation';
        RAISE NOTICE '========================================';
        RAISE NOTICE '📊 ESTADÍSTICAS:';
        RAISE NOTICE '   Registros cargados: %', record_count;
        RAISE NOTICE '⏱️  TIEMPOS:';
        RAISE NOTICE '   • TRUNCATE: %', truncate_duration;
        RAISE NOTICE '   • COPY: %', copy_duration;
        RAISE NOTICE '   • CARGA TOTAL (truncate + copy): %', load_duration;
        RAISE NOTICE '   • TRANSACCIÓN COMPLETA: %', total_duration;
        RAISE NOTICE '========================================';

        	-- Fase 1: TRUNCATE para brazil_state_list
        start_truncate := clock_timestamp();
        RAISE NOTICE '🗑️  Ejecutando TRUNCATE...';
        
        TRUNCATE TABLE bronze.blog_mds_gov_br_brazil_state_list;
        
        truncate_duration := clock_timestamp() - start_truncate;
        RAISE NOTICE '✅ TRUNCATE completado en: %', truncate_duration;
        
        -- Fase 2: COPY para olist_orders
        start_copy := clock_timestamp();
        RAISE NOTICE '📥 Ejecutando COPY desde CSV...';
        
        COPY bronze.blog_mds_gov_br_brazil_state_list FROM '/import_data/blog.mds.gov.br.lista_estados_brasil.csv' 
        DELIMITER E';' 
        CSV HEADER;
        
        end_copy := clock_timestamp();
        copy_duration := end_copy - start_copy;
    
        
        -- Cálculos finales de tiempos
        total_duration := end_copy - start_total;
        load_duration := end_copy - start_truncate;  -- truncate + copy
        
        -- REPORTE FINAL
        RAISE NOTICE '========================================';
        RAISE NOTICE '🎉 CARGA COMPLETADA EXITOSAMENTE para bronze.blog_mds_gov_br_brazil_state_list';
        RAISE NOTICE '========================================';
        RAISE NOTICE '📊 ESTADÍSTICAS:';
        RAISE NOTICE '   Registros cargados: %', record_count;
        RAISE NOTICE '⏱️  TIEMPOS:';
        RAISE NOTICE '   • TRUNCATE: %', truncate_duration;
        RAISE NOTICE '   • COPY: %', copy_duration;
        RAISE NOTICE '   • CARGA TOTAL (truncate + copy): %', load_duration;
        RAISE NOTICE '   • TRANSACCIÓN COMPLETA: %', total_duration;
        RAISE NOTICE '========================================';
        
        
    EXCEPTION
        WHEN OTHERS THEN
            -- En caso de error, mostrar tiempos hasta el fallo
            DECLARE
                error_time TIMESTAMP := clock_timestamp();
            BEGIN
                RAISE NOTICE '========================================';
                RAISE NOTICE '❌ ERROR DURANTE LA CARGA';
                RAISE NOTICE '========================================';
                RAISE NOTICE 'Mensaje de error: %', SQLERRM;
                RAISE NOTICE 'Tiempo transcurrido: %', (error_time - start_total);
                RAISE NOTICE '========================================';
                RAISE;
            END;
    END;
END $$;