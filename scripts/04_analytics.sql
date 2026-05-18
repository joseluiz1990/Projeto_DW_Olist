-- ============================================================================
-- SCRIPT: 04_analytics.sql
-- ETAPA: 5. CONSULTAS ANALÍTICAS (INSIGHTS DE NEGÓCIO)
-- DESCRIÇÃO: Executa consultas complexas (Window Functions, Aggregations, Joins)
--            para extrair os KPIs e responder aos requisitos do projeto.
-- REQUISITO: Execução rápida (< 30s) impulsionada pela estrutura colunar do DW.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- PERGUNTA 1: Qual é a evolução mensal do faturamento total, quantidade de 
--             itens vendidos e do ticket médio da plataforma? (KPI & TEMPORAL)
-- ----------------------------------------------------------------------------
SELECT 
    d.year AS ano,
    d.month AS numero_mes,
    d.month_name AS mes,
    COUNT(DISTINCT f.order_id) AS total_pedidos,
    SUM(f.quantity) AS total_itens_vendidos,
    ROUND(SUM(f.revenue), 2) AS faturamento_total,
    ROUND(SUM(f.revenue) / COUNT(DISTINCT f.order_id), 2) AS ticket_medio_por_pedido
FROM dw.fact_sales f
JOIN dw.dim_date d ON f.date_key = d.date_key
GROUP BY d.year, d.month, d.month_name
ORDER BY d.year, d.month;


-- ----------------------------------------------------------------------------
-- PERGUNTA 2: Quais são as TOP 10 categorias de produtos em receita acumulada
--             e qual a participação de cada uma no total? (RANKING / TOP N)
-- ----------------------------------------------------------------------------
WITH receita_por_categoria AS (
    SELECT 
        COALESCE(p.category_name_pt, 'Não Informado') AS categoria,
        SUM(f.revenue) AS receita_categoria
    FROM dw.fact_sales f
    JOIN dw.dim_product p ON f.product_key = p.product_key
    GROUP BY p.category_name_pt
)
SELECT 
    categoria,
    ROUND(receita_categoria, 2) AS receita_total,
    ROUND((receita_categoria / SUM(receita_categoria) OVER ()) * 100, 2) AS pct_participacao
FROM receita_por_categoria
ORDER BY receita_total DESC
LIMIT 10;


-- ----------------------------------------------------------------------------
-- PERGUNTA 3: Quais são os 5 estados (UF) dos compradores com maior ticket médio
--             e qual a avaliação média dos vendedores locais? (MULTIDIMENSIONAL)
-- ----------------------------------------------------------------------------
SELECT 
    c.state AS uf_comprador,
    COUNT(DISTINCT f.order_id) AS total_pedidos,
    ROUND(SUM(f.revenue) / COUNT(DISTINCT f.order_id), 2) AS ticket_medio_comprador,
    ROUND(AVG(f.review_score), 2) AS avaliacao_media_pedidos
FROM dw.fact_sales f
JOIN dw.dim_customer c ON f.customer_key = c.customer_key
GROUP BY c.state
ORDER BY ticket_medio_comprador DESC
LIMIT 5;


-- ----------------------------------------------------------------------------
-- PERGUNTA 4: Como os vendedores se distribuem na classificação da Curva ABC
--             baseada no faturamento gerado por cada um? (DESAFIO / CURVA ABC)
-- ----------------------------------------------------------------------------
WITH receita_vendedor AS (
    SELECT 
        s.seller_id,
        SUM(f.revenue) AS receita_total
    FROM dw.fact_sales f
    JOIN dw.dim_seller s ON f.seller_key = s.seller_key
    GROUP BY s.seller_id
),
acumulado_vendedor AS (
    SELECT 
        seller_id,
        receita_total,
        SUM(receita_total) OVER (ORDER BY receita_total DESC) / SUM(receita_total) OVER () AS pct_acumulado
    FROM receita_vendedor
),
classificacao_abc AS (
    SELECT 
        seller_id,
        receita_total,
        CASE 
            WHEN pct_acumulado <= 0.80 THEN 'A'
            WHEN pct_acumulado <= 0.95 THEN 'B'
            ELSE 'C'
        END AS classe_abc
    FROM acumulado_vendedor
)
SELECT 
    classe_abc,
    COUNT(*) AS total_vendedores,
    ROUND(SUM(receita_total), 2) AS faturamento_da_classe,
    ROUND((SUM(receita_total) / (SELECT SUM(receita_total) FROM receita_vendedor)) * 100, 2) AS pct_faturamento
FROM classificacao_abc
GROUP BY classe_abc
ORDER BY classe_abc;


-- ----------------------------------------------------------------------------
-- PERGUNTA 5: Qual é a taxa de retenção/recompra dos clientes com base no mês
--             da primeira compra feita na plataforma? (COHORT / RETENÇÃO)
-- ----------------------------------------------------------------------------
WITH primeiro_pedido_cliente AS (
    -- Identifica o mês de estreia (Cohort) de cada cliente único
    SELECT 
        c.customer_unique_id,
        MIN(date_trunc('month', d.full_date)) AS mes_cohort
    FROM dw.fact_sales f
    JOIN dw.dim_customer c ON f.customer_key = c.customer_key
    JOIN dw.dim_date d ON f.date_key = d.date_key
    GROUP BY c.customer_unique_id
),
pedidos_futuros AS (
    -- Identifica todos os meses em que o cliente realizou compras
    SELECT DISTINCT
        c.customer_unique_id,
        date_trunc('month', d.full_date) AS mes_compra
    FROM dw.fact_sales f
    JOIN dw.dim_customer c ON f.customer_key = c.customer_key
    JOIN dw.dim_date d ON f.date_key = d.date_key
),
tamanho_cohort AS (
    -- Conta quantos clientes novos entraram em cada mês
    SELECT mes_cohort, COUNT(*) AS clientes_iniciais
    FROM primeiro_pedido_cliente
    GROUP BY mes_cohort
)
SELECT 
    strftime(p.mes_cohort, '%Y-%m') AS cohort_mes,
    tc.clientes_iniciais,
    -- Calcula quantos meses se passaram desde a primeira compra
    ((EXTRACT(year FROM f.mes_compra) - EXTRACT(year FROM p.mes_cohort)) * 12) + 
     (EXTRACT(month FROM f.mes_compra) - EXTRACT(month FROM p.mes_cohort)) AS meses_decorridos,
    COUNT(DISTINCT f.customer_unique_id) AS clientes_ativos,
    ROUND((COUNT(DISTINCT f.customer_unique_id)::NUMERIC / tc.clientes_iniciais) * 100, 2) AS taxa_retencao_pct
FROM primeiro_pedido_cliente p
JOIN pedidos_futuros f ON p.customer_unique_id = f.customer_unique_id
JOIN tamanho_cohort tc ON p.mes_cohort = tc.mes_cohort
-- Filtra para analisar apenas o primeiro ano após a entrada (até 6 meses para visualização limpa)
WHERE meses_decorridos BETWEEN 0 AND 6
GROUP BY p.mes_cohort, tc.clientes_iniciais, meses_decorridos
ORDER BY p.mes_cohort, meses_decorridos;