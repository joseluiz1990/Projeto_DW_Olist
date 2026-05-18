-- ============================================================================
-- SCRIPT: 01_oltp.sql
-- ETAPA: 2. CAMADA OLTP (OPERACIONAL)
-- DESCRIÇÃO: Lê as views de staging e cria tabelas físicas estruturadas.
--            Aplica a remoção de duplicatas e o tratamento de nulos.
-- IDEMPOTÊNCIA: Utiliza 'DROP TABLE IF EXISTS' antes de cada criação.
-- ============================================================================

-- Apaga o schema antigo e TUDO o que estiver dentro dele (tabelas e chaves)
DROP SCHEMA IF EXISTS oltp CASCADE;

-- Cria o schema novamente do zero, totalmente limpo
CREATE SCHEMA oltp;

-- ----------------------------------------------------------------------------
-- 1. TABELA: oltp.customers
-- ----------------------------------------------------------------------------

CREATE TABLE oltp.customers AS
SELECT DISTINCT
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix AS zip_code_prefix,
    COALESCE(customer_city, 'Não Informado') AS city,
    COALESCE(customer_state, 'ND') AS state
FROM staging.stg_customers;

-- ----------------------------------------------------------------------------
-- 2. TABELA: oltp.products
-- ----------------------------------------------------------------------------

CREATE TABLE oltp.products AS
SELECT DISTINCT
    p.product_id,
    COALESCE(t.product_category_name_english, p.product_category_name, 'Não Informado') AS category_name_en,
    COALESCE(p.product_category_name, 'Não Informado') AS category_name_pt,
    COALESCE(p.product_name_lenght, 0)::INT AS name_length,
    COALESCE(p.product_description_lenght, 0)::INT AS description_length,
    COALESCE(p.product_photos_qty, 0)::INT AS photos_qty,
    COALESCE(p.product_weight_g, 0)::INT AS weight_g,
    COALESCE(p.product_length_cm, 0)::INT AS length_cm,
    COALESCE(p.product_height_cm, 0)::INT AS height_cm,
    COALESCE(p.product_width_cm, 0)::INT AS width_cm
FROM staging.stg_products p
LEFT JOIN staging.stg_category_translation t 
    ON p.product_category_name = t.product_category_name;

-- ----------------------------------------------------------------------------
-- 3. TABELA: oltp.sellers
-- ----------------------------------------------------------------------------

CREATE TABLE oltp.sellers AS
SELECT DISTINCT
    seller_id,
    seller_zip_code_prefix AS zip_code_prefix,
    COALESCE(seller_city, 'Não Informado') AS city,
    COALESCE(seller_state, 'ND') AS state
FROM staging.stg_sellers;

-- ----------------------------------------------------------------------------
-- 4. TABELA: oltp.geolocation (Agrupada para evitar chaves duplicadas no CEP)
-- ----------------------------------------------------------------------------

CREATE TABLE oltp.geolocation AS
SELECT 
    geolocation_zip_code_prefix AS zip_code_prefix,
    AVG(geolocation_lat) AS geolocation_lat,
    AVG(geolocation_lng) AS geolocation_lng,
    ANY_VALUE(geolocation_city) AS city,
    ANY_VALUE(geolocation_state) AS state
FROM staging.stg_geolocation
GROUP BY geolocation_zip_code_prefix;

-- ----------------------------------------------------------------------------
-- 5. TABELA: oltp.orders (Cabeçalho de Pedidos)
-- ----------------------------------------------------------------------------

CREATE TABLE oltp.orders AS
SELECT DISTINCT
    order_id,
    customer_id,
    COALESCE(order_status, 'Não Informado') AS order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date
FROM staging.stg_orders;

-- ----------------------------------------------------------------------------
-- 6. TABELA: oltp.order_items (Itens de Pedidos)
-- ----------------------------------------------------------------------------

CREATE TABLE oltp.order_items AS
SELECT 
    order_id,
    order_item_id::INT AS order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price::NUMERIC AS price,
    freight_value::NUMERIC AS freight_value
FROM staging.stg_order_items;

-- ----------------------------------------------------------------------------
-- 7. TABELA: oltp.order_payments (Pagamentos)
-- ----------------------------------------------------------------------------

CREATE TABLE oltp.order_payments AS
SELECT 
    order_id,
    payment_sequential::INT AS payment_sequential,
    COALESCE(payment_type, 'Não Informado') AS payment_type,
    COALESCE(payment_installments, 1)::INT AS payment_installments,
    payment_value::NUMERIC AS payment_value
FROM staging.stg_order_payments;

-- ----------------------------------------------------------------------------
-- 8. TABELA: oltp.order_reviews (Avaliações)
-- ----------------------------------------------------------------------------

CREATE TABLE oltp.order_reviews AS
SELECT 
    review_id,
    order_id,
    COALESCE(review_score, 0)::INT AS review_score,
    review_comment_title,
    review_comment_message,
    review_creation_date,
    review_answer_timestamp
FROM staging.stg_order_reviews;

-- ============================================================================
-- VALIDAÇÕES DA CAMADA OLTP
-- Verifica se as tabelas físicas foram criadas com volumetria consistente
-- ============================================================================
SELECT 'oltp.orders' AS tabela, COUNT(*) AS total_linhas FROM oltp.orders
UNION ALL
SELECT 'oltp.order_items', COUNT(*) FROM oltp.order_items
UNION ALL
SELECT 'oltp.products', COUNT(*) FROM oltp.products;