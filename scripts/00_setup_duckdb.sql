
-- ============================================================================
-- SCRIPT: 00_staging.sql
-- ETAPA: 1. STAGING AREA
-- DESCRIÇÃO: Criação de views temporárias que lêem diretamente os 9 arquivos
--            CSV do dataset Olist utilizando a deteção automática do DuckDB.
--            Não são aplicadas transformações ou limpezas nesta camada.
-- INDEMPOTÊNCIA: Utiliza 'CREATE OR REPLACE VIEW' para permitir reexecução.
-- ============================================================================

-- Apaga o schema antigo e TUDO o que estiver dentro dele (tabelas e chaves)
DROP SCHEMA IF EXISTS staging CASCADE;

-- Cria o schema novamente do zero, totalmente limpo
CREATE SCHEMA staging;

-- 1. View para o cadastro de clientes
CREATE OR REPLACE VIEW staging.stg_customers AS 
SELECT * FROM read_csv_auto('data/olist/olist_customers_dataset.csv');

-- 2. View para a geolocalização e coordenadas dos CEPs
CREATE OR REPLACE VIEW staging.stg_geolocation AS 
SELECT * FROM read_csv_auto('data/olist/olist_geolocation_dataset.csv');

-- 3. View para os itens contidos em cada pedido
CREATE OR REPLACE VIEW staging.stg_order_items AS 
SELECT * FROM read_csv_auto('data/olist/olist_order_items_dataset.csv');

-- 4. View para os métodos e detalhes de pagamento dos pedidos
CREATE OR REPLACE VIEW staging.stg_order_payments AS 
SELECT * FROM read_csv_auto('data/olist/olist_order_payments_dataset.csv');

-- 5. View para as avaliações e notas dadas pelos clientes
CREATE OR REPLACE VIEW staging.stg_order_reviews AS 
SELECT * FROM read_csv_auto('data/olist/olist_order_reviews_dataset.csv');

-- 6. View para o cabeçalho e status dos pedidos
CREATE OR REPLACE VIEW staging.stg_orders AS 
SELECT * FROM read_csv_auto('data/olist/olist_orders_dataset.csv');

-- 7. View para o cadastro técnico dos produtos
CREATE OR REPLACE VIEW staging.stg_products AS 
SELECT * FROM read_csv_auto('data/olist/olist_products_dataset.csv');

-- 8. View para o cadastro de vendedores parceiros (marketplace)
CREATE OR REPLACE VIEW staging.stg_sellers AS 
SELECT * FROM read_csv_auto('data/olist/olist_sellers_dataset.csv');

-- 9. View para a tabela de tradução dos nomes das categorias de produtos
CREATE OR REPLACE VIEW staging.stg_category_translation AS 
SELECT * FROM read_csv_auto('data/olist/product_category_name_translation.csv');

-- ============================================================================
-- VALIDAÇÃO DA CAMADA DE STAGING
-- Consultas rápidas para garantir que as views estão a aceder aos ficheiros
-- ============================================================================
SELECT 'stg_orders' AS tabela, COUNT(*) AS total_linhas FROM staging.stg_orders
UNION ALL
SELECT 'stg_order_items', COUNT(*) FROM staging.stg_order_items;

