-- ============================================================================
-- SCRIPT: 02_dw_model.sql
-- ETAPA: 3. MODELO DO DATA WAREHOUSE (ESTRUTURA VAZIA)
-- DESCRIÇÃO: Cria o schema analítico e a estrutura de tabelas do Esquema Estrela.
--            Define chaves substitutas (Surrogate Keys) e restrições relacionais.
-- IDEMPOTÊNCIA: Limpeza completa do schema usando DROP SCHEMA ... CASCADE.
-- ============================================================================

-- Limpa o ambiente analítico anterior para evitar conflitos de reexecução
DROP SCHEMA IF EXISTS dw CASCADE;

-- Cria o schema do Data Warehouse limpo
CREATE SCHEMA dw;

-- ----------------------------------------------------------------------------
-- TABELA: dw.dim_date (Dimensão de Tempo)
-- ----------------------------------------------------------------------------
CREATE TABLE dw.dim_date (
    date_key INT PRIMARY KEY,
    full_date DATE NOT NULL,
    year INT NOT NULL,
    month INT NOT NULL,
    month_name VARCHAR NOT NULL,
    quarter INT NOT NULL,
    day_of_month INT NOT NULL,
    day_name VARCHAR NOT NULL
);

-- ----------------------------------------------------------------------------
-- TABELA: dw.dim_geolocation (Tabela Satélite / Outrigger Geográfico)
-- ----------------------------------------------------------------------------
CREATE TABLE dw.dim_geolocation (
    zip_code_prefix VARCHAR PRIMARY KEY,
    geolocation_lat DOUBLE,
    geolocation_lng DOUBLE,
    city VARCHAR,
    state VARCHAR
);

-- ----------------------------------------------------------------------------
-- TABELA: dw.dim_customer (Dimensão de Clientes com suporte a SCD Tipo 2)
-- ----------------------------------------------------------------------------
CREATE TABLE dw.dim_customer (
    customer_key BIGINT PRIMARY KEY, -- Surrogate Key gerada pelo DW
    customer_id VARCHAR NOT NULL,
    customer_unique_id VARCHAR NOT NULL,
    zip_code_prefix VARCHAR,
    city VARCHAR,
    state VARCHAR,
    -- Campos de controle de histórico e vigência (SCD2)
    start_date TIMESTAMP NOT NULL,
    end_date TIMESTAMP,
    is_current BOOLEAN NOT NULL
);

-- ----------------------------------------------------------------------------
-- TABELA: dw.dim_product (Dimensão de Produtos)
-- ----------------------------------------------------------------------------
CREATE TABLE dw.dim_product (
    product_key BIGINT PRIMARY KEY, -- Surrogate Key
    product_id VARCHAR NOT NULL,
    category_name_pt VARCHAR,
    category_name_en VARCHAR,
    name_length INT,
    description_length INT,
    photos_qty INT,
    weight_g INT,
    length_cm INT,
    height_cm INT,
    width_cm INT,
    is_current BOOLEAN NOT NULL -- Controle simples de vigência cadastral
);

-- ----------------------------------------------------------------------------
-- TABELA: dw.dim_seller (Dimensão de Vendedores)
-- ----------------------------------------------------------------------------
CREATE TABLE dw.dim_seller (
    seller_key BIGINT PRIMARY KEY, -- Surrogate Key
    seller_id VARCHAR NOT NULL,
    zip_code_prefix VARCHAR,
    city VARCHAR,
    state VARCHAR
);

-- ----------------------------------------------------------------------------
-- TABELA FATO: dw.fact_sales (Fato Centralizada Expandida)
-- Consolida itens, cabeçalhos, pagamentos e avaliações
-- ----------------------------------------------------------------------------
CREATE TABLE dw.fact_sales (
    -- Chaves de Degeneração (Rastreabilidade do E-commerce)
    order_id VARCHAR NOT NULL,
    order_item_id INT NOT NULL,
    payment_sequential INT NOT NULL,
    
    -- Chaves Estrangeiras conectando ao Esquema Estrela
    date_key INT NOT NULL,
    customer_key BIGINT NOT NULL,
    product_key BIGINT NOT NULL,
    seller_key BIGINT NOT NULL,
    
    -- Métricas / Fatos Quantitativos
    quantity INT NOT NULL,
    price NUMERIC NOT NULL,
    freight_value NUMERIC NOT NULL,
    revenue NUMERIC NOT NULL,
    payment_type VARCHAR,
    payment_installments INT,
    payment_value NUMERIC,
    review_score INT,
    shipping_limit_date TIMESTAMP,
    
    -- Definição das Chaves Estrangeiras de Integridade
    FOREIGN KEY (date_key) REFERENCES dw.dim_date(date_key),
    FOREIGN KEY (customer_key) REFERENCES dw.dim_customer(customer_key),
    FOREIGN KEY (product_key) REFERENCES dw.dim_product(product_key),
    FOREIGN KEY (seller_key) REFERENCES dw.dim_seller(seller_key)
);

-- ============================================================================
-- VALIDAÇÃO DA CAMADA DW
-- Confirma se as tabelas estruturais foram provisionadas corretamente (vazias)
-- ============================================================================
SELECT table_name, column_count 
FROM duckdb_tables() 
WHERE schema_name = 'dw' 
ORDER BY table_name;