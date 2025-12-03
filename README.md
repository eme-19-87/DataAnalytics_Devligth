# 📦 Proyecto Final -- Data Warehouse para E-Commerce Brazil (Olist)

Este repositorio contiene el desarrollo completo de un **Data
Warehouse** construido a partir del conjunto de datos público de
comercio electrónico de Brasil publicado por **Olist Store** en Kaggle.\
El proyecto adopta la **arquitectura Medallón (Bronce → Plata → Oro)** e
implementa procesos ETL para limpieza, normalización, modelado
dimensional y análisis final.

## 🧭 Tabla de Contenidos

1.  🎯 Objetivo del Proyecto
2.  🛠️ Herramientas Utilizadas
3.  🏗️ Arquitectura
4.  📂 Sistema Fuente (Datasets)
5.  🥉 Capa Bronce
6.  🥈 Capa Plata -- Limpieza y Estandarización
7.  🥇 Capa Oro -- Modelo Dimensional
8.  📊 Dashboards en Metabase
9.  📁 Estructura del Repositorio
10. 📚 Referencias

## 🎯 Objetivo del Proyecto

El objetivo es construir un **Data Warehouse robusto y confiable**
que: - Integre datos provenientes de archivos CSV crudos. - Aplique
procesos de limpieza, estandarización y control de calidad. - Modele un
esquema dimensional eficiente para análisis. - Permita generar
dashboards y reportes de valor. - Mejore la toma de decisiones para un
entorno de comercio electrónico.

## 🛠️ Herramientas Utilizadas

  Herramienta   Uso
  ------------- ------------------------------
  PostgreSQL    Motor del Data Warehouse.
  Metabase      Visualización de dashboards.
  GitHub        Control de versiones.
  Draw.io       Diagramas de arquitectura.
  Python        Scripts auxiliares.

## 🏗️ Arquitectura

La arquitectura sigue el modelo **Medallón**: \### 🥉 Bronce\
Datos en bruto, sin transformación. \### 🥈 Plata\
Limpieza, estandarización e imputación. \### 🥇 Oro\
Modelo dimensional orientado a análisis.

## 📂 Sistema Fuente (Datasets)

-   olist_customers_dataset.csv\
-   olist_geolocation_dataset.csv\
-   olist_orders_dataset.csv\
-   olist_order_items_dataset.csv\
-   olist_order_payments_dataset.csv\
-   olist_order_reviews_dataset.csv\
-   olist_products_dataset.csv\
-   olist_sellers_dataset.csv\
-   product_category_name_translation.csv

## 🥉 Capa Bronce

Carga cruda mediante tablas espejo y procesos Truncate + Insert.

## 🥈 Capa Plata -- Limpieza y Estandarización

Incluye limpieza de productos, geolocalización, clientes, vendedores,
órdenes, ítems de órdenes, pagos y reseñas.

## 🥇 Capa Oro -- Modelo Dimensional

### Dimensiones

-   dim_customers\
-   dim_sellers\
-   dim_products\
-   dim_geolocation\
-   dim_date\
-   dim_payments\
-   dim_categories\
-   dim_reviews

### Hechos

-   fact_orders\
-   fact_order_items

## 📊 Dashboards en Metabase

Incluyen análisis de ventas, logística, recompras, satisfacción del
cliente y más.

## 📁 Estructura del Repositorio

📦 ecommerce-brazil-dw\
├── b ronze/\
├── silver/\
├── gold/\
├── data/raw/\
├── notebooks/\
├── diagrams/\
└── README.md

## 📚 Referencias

1.  Olist Dataset (Kaggle)\
2.  Baraa Khatib -- Data Warehouse Project\
3.  SQL Data Warehouse from Scratch\
4.  Lista oficial de municipios de Brasil
