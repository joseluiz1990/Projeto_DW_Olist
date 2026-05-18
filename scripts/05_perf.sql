-- ============================================================================
-- SCRIPT: 05_perf.sql
-- ETAPA: 3.5 PERFORMANCE E OTIMIZAÇÃO (BÔNUS)
-- ============================================================================

-- [PASSO 1] ANÁLISE DO PLANO ORIGINAL (Sem Otimização)
.print '------------------------------------------------------------'
.print '🔍 Analisando Plano de Execução da Query Original...'
.print '------------------------------------------------------------'

EXPLAIN 
SELECT 
    d.year,
    d.month_name,
    COALESCE(p.category_name_pt, 'Não Informado') AS categoria,
    SUM(f.revenue) AS receita_total,
    COUNT(DISTINCT f.order_id) AS total_pedidos
FROM dw.fact_sales f
JOIN dw.dim_date d ON f.date_key = d.date_key
JOIN dw.dim_product p ON f.product_key = p.product_key
GROUP BY d.year, d.month, d.month_name, p.category_name_pt;


-- [PASSO 2] IMPLEMENTAÇÃO DA TABELA AGREGADA (DATA MART)
DROP TABLE IF EXISTS dw.agg_monthly_sales_by_category CASCADE;

CREATE TABLE dw.agg_monthly_sales_by_category AS
SELECT 
    d.year,
    d.month,
    d.month_name,
    COALESCE(p.category_name_pt, 'Não Informado') AS category_name,
    SUM(f.revenue) AS revenue,
    COUNT(DISTINCT f.order_id) AS num_orders,
    SUM(f.quantity) AS total_quantity
FROM dw.fact_sales f
JOIN dw.dim_date d ON f.date_key = d.date_key
JOIN dw.dim_product p ON f.product_key = p.product_key
GROUP BY d.year, d.month, d.month_name, p.category_name_pt;


-- [PASSO 3] ADIÇÃO DE ÍNDICE COMPLEMENTAR
CREATE INDEX idx_agg_category ON dw.agg_monthly_sales_by_category(category_name);


-- [PASSO 4] ANÁLISE DO PLANO OTIMIZADO
.print '------------------------------------------------------------'
.print '🚀 Analisando Plano de Execução na Tabela Agregada Otimizada...'
.print '------------------------------------------------------------'

EXPLAIN 
SELECT 
    year,
    month_name,
    category_name,
    revenue,
    num_orders
FROM dw.agg_monthly_sales_by_category;


-- ============================================================================
-- VALIDAÇÃO DE PERFORMANCE E VOLUMETRIA COMPRIMIDA
-- ============================================================================
.print '------------------------------------------------------------'
.print '📊 Comparativo de Volumetria Escaneada para o Relatório:'
.print '------------------------------------------------------------'

SELECT 'Tabela Fato Original' AS estrutura, COUNT(*) AS linhas_processadas FROM dw.fact_sales
UNION ALL
SELECT 'Tabela Agregada Otimizada', COUNT(*) FROM dw.agg_monthly_sales_by_category;