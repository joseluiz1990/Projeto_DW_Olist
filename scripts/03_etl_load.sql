-- ============================================================================
-- SCRIPT: 03_etl_load.sql
-- ETAPA: 4. ETL CARGA (POPULAR O DATA WAREHOUSE)
-- DESCRIÇÃO: Processa os dados da camada OLTP e carrega o Esquema Estrela.
--            Gera chaves substitutas (Surrogate Keys) e popula o SCD Tipo 2.
-- INDEMPOTÊNCIA: Como o script 02 já recria a estrutura limpa, as cargas
--                são diretas via INSERT INTO.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. POPULAR DIMENSÃO: dw.dim_date
-- ----------------------------------------------------------------------------
-- Gera dinamicamente todas as datas entre 2016 e 2018 (período do dataset Olist)
INSERT INTO dw.dim_date
SELECT 
    (strftime(d, '%Y%m%d'))::INT AS date_key,
    d::DATE AS full_date,
    EXTRACT(year FROM d)::INT AS year,
    EXTRACT(month FROM d)::INT AS month,
    CASE EXTRACT(month FROM d)
        WHEN 1 THEN 'Janeiro' WHEN 2 THEN 'Fevereiro' WHEN 3 THEN 'Março'
        WHEN 4 THEN 'Abril' WHEN 5 THEN 'Maio' WHEN 6 THEN 'Junho'
        WHEN 7 THEN 'Julho' WHEN 8 THEN 'Agosto' WHEN 9 THEN 'Setembro'
        WHEN 10 THEN 'Outubro' WHEN 11 THEN 'Novembro' WHEN 12 THEN 'Dezembro'
    END AS month_name,
    EXTRACT(quarter FROM d)::INT AS quarter,
    EXTRACT(day FROM d)::INT AS day_of_month,
    CASE EXTRACT(dow FROM d)
        WHEN 0 THEN 'Domingo' WHEN 1 THEN 'Segunda-feira' WHEN 2 THEN 'Terça-feira'
        WHEN 3 THEN 'Quarta-feira' WHEN 4 THEN 'Quinta-feira' WHEN 5 THEN 'Sexta-feira'
        WHEN 6 THEN 'Sábado'
    END AS day_name
FROM generate_series(DATE '2016-01-01', DATE '2018-12-31', INTERVAL 1 DAY) AS t(d);

-- ----------------------------------------------------------------------------
-- 2. POPULAR DIMENSÃO: dw.dim_geolocation
-- ----------------------------------------------------------------------------
INSERT INTO dw.dim_geolocation
SELECT zip_code_prefix, geolocation_lat, geolocation_lng, city, state 
FROM oltp.geolocation;

-- ----------------------------------------------------------------------------
-- 3. POPULAR DIMENSÃO: dw.dim_customer (Inicialização do Histórico SCD2)
-- ----------------------------------------------------------------------------
INSERT INTO dw.dim_customer
SELECT 
    row_number() OVER () AS customer_key, -- Surrogate Key numérica
    customer_id,
    customer_unique_id,
    zip_code_prefix,
    city,
    state,
    '2016-01-01 00:00:00'::TIMESTAMP AS start_date, -- Marco inicial genérico do dataset
    NULL::TIMESTAMP AS end_date,
    TRUE AS is_current
FROM oltp.customers;

-- ----------------------------------------------------------------------------
-- 4. POPULAR DIMENSÃO: dw.dim_product
-- ----------------------------------------------------------------------------
INSERT INTO dw.dim_product
SELECT 
    row_number() OVER () AS product_key, -- Surrogate Key
    product_id,
    category_name_pt,
    category_name_en,
    name_length,
    description_length,
    photos_qty,
    weight_g,
    length_cm,
    height_cm,
    width_cm,
    TRUE AS is_current
FROM oltp.products;

-- ----------------------------------------------------------------------------
-- 5. POPULAR DIMENSÃO: dw.dim_seller
-- ----------------------------------------------------------------------------
INSERT INTO dw.dim_seller
SELECT 
    row_number() OVER () AS seller_key, -- Surrogate Key
    seller_id,
    zip_code_prefix,
    city,
    state
FROM oltp.sellers;

-- ----------------------------------------------------------------------------
-- 6. POPULAR TABELA FATO CENTRAL: dw.fact_sales
-- ----------------------------------------------------------------------------
INSERT INTO dw.fact_sales
SELECT 
    i.order_id,
    i.order_item_id,
    COALESCE(p.payment_sequential, 1) AS payment_sequential,
    
    -- Mapeamento e conversão da data de aprovação do pedido para a chave temporal
    COALESCE(strftime(o.order_approved_at, '%Y%m%d'), strftime(o.order_purchase_timestamp, '%Y%m%d'))::INT AS date_key,
    
    -- Busca as Chaves Substitutas associadas corretas (Tratando registros órfãos com chaves padrão se necessário)
    COALESCE(dc.customer_key, -1) AS customer_key,
    COALESCE(dp.product_key, -1) AS product_key,
    COALESCE(ds.seller_key, -1) AS seller_key,
    
    -- Fatos e Métricas Aditivas combinadas
    1 AS quantity,
    i.price,
    i.freight_value,
    (i.price * 1) AS revenue,
    p.payment_type,
    p.payment_installments,
    p.payment_value,
    r.review_score,
    i.shipping_limit_date

FROM oltp.order_items i
INNER JOIN oltp.orders o ON i.order_id = o.order_id
LEFT JOIN oltp.order_payments p ON i.order_id = p.order_id
LEFT JOIN oltp.order_reviews r ON i.order_id = r.order_id
LEFT JOIN dw.dim_customer dc ON o.customer_id = dc.customer_id AND dc.is_current = TRUE
LEFT JOIN dw.dim_product dp ON i.product_id = dp.product_id AND dp.is_current = TRUE
LEFT JOIN dw.dim_seller ds ON i.seller_id = ds.seller_id;

-- ============================================================================
-- SESSÃO DE VALIDAÇÃO REQUISITADA (CONTAGEM E INTEGRIDADE)
-- ============================================================================
SELECT 'dw.dim_customer' AS tabela, COUNT(*) AS total_linhas FROM dw.dim_customer
UNION ALL
SELECT 'dw.dim_product', COUNT(*) FROM dw.dim_product
UNION ALL
SELECT 'dw.fact_sales (Fato)', COUNT(*) FROM dw.fact_sales
UNION ALL
SELECT 'Erros de Integridade (Chaves Nulas na Fato)', COUNT(*) FROM dw.fact_sales WHERE customer_key IS NULL OR product_key IS NULL;