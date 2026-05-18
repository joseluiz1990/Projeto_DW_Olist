"""
Gera gráficos de análise do Data Warehouse de e-commerce
"""
import os
import duckdb
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots

# Conectar ao banco DuckDB
conn = duckdb.connect('demo.duckdb')

print("=" * 60)
print("Gerando gráficos do Data Warehouse...")
print("=" * 60)

# Estatísticas básicas
total_items = conn.execute("SELECT COUNT(*) FROM dw.fact_sales").fetchone()[0]
total_revenue = conn.execute("SELECT SUM(revenue) FROM dw.fact_sales").fetchone()[0]
print(f"\n📊 Dataset: {total_items:,} itens | R$ {total_revenue:,.2f} de receita")

# Garante que a pasta 'Graficos' exista para salvar as imagens
os.makedirs('Graficos', exist_ok=True)

# ============================================================================
# Gráfico 1: Linha (evolução no tempo)
# ============================================================================
query1 = """
SELECT 
    (year::VARCHAR || '-' || lpad(month::VARCHAR, 2, '0')) AS mes, 
    SUM(revenue) AS vendas
FROM dw.fact_sales f
JOIN dw.dim_date d ON f.date_key = d.date_key
GROUP BY year, month
ORDER BY year, month
"""
df1 = conn.execute(query1).df()
if not df1.empty:
    fig1 = px.line(df1, x='mes', y='vendas', 
                  title='Evolução de Vendas',
                  labels={'vendas': 'Faturamento (R$)', 'mes': 'Mês'},
                  template='plotly_white',
                  markers=True)
    fig1.update_traces(line_color='#1f77b4', line_width=3)
    fig1.write_image('Graficos/grafico_1_evolucao.png', width=1200, height=600)
    print("✅ Gráfico 1 salvo: Graficos/grafico_1_evolucao.png")
else:
    print("⚠️  Gráfico 1: sem dados")

# ============================================================================
# Gráfico 2: Barras (comparação)
# ============================================================================
query2 = """
SELECT 
    COALESCE(p.category_name_pt, 'Não Informado') AS produto,
    SUM(f.revenue) AS receita
FROM dw.fact_sales f
JOIN dw.dim_product p ON f.product_key = p.product_key AND p.is_current
GROUP BY p.category_name_pt
ORDER BY receita DESC
LIMIT 10
"""
df2 = conn.execute(query2).df()
if not df2.empty:
    fig2 = px.bar(df2, x='receita', y='produto', 
                  title='Top 10 Produtos por Faturamento',
                  labels={'receita': 'Receita (R$)', 'produto': 'Categoria / Produto'},
                  template='plotly_white',
                  orientation='h',
                  color='receita',
                  color_continuous_scale='Blues')
    fig2.update_layout(yaxis={'categoryorder': 'total ascending'}, coloraxis_showscale=False)
    fig2.write_image('Graficos/grafico_2_top_produtos.png', width=1200, height=600)
    print("✅ Gráfico 2 salvo: Graficos/grafico_2_top_produtos.png")
else:
    print("⚠️  Gráfico 2: sem dados")

# ============================================================================
# Gráfico 3: Mapa de Calor OU Dispersão (correlação)
# ============================================================================
query3 = """
SELECT 
    c.state AS estado,
    SUM(f.revenue) / COUNT(DISTINCT f.order_id) AS ticket_medio,
    AVG(f.review_score) AS avaliacao_media
FROM dw.fact_sales f
JOIN dw.dim_customer c ON f.customer_key = c.customer_key AND c.is_current
GROUP BY c.state
"""
df3 = conn.execute(query3).df()
if not df3.empty:
    fig3 = px.scatter(df3, x='ticket_medio', y='avaliacao_media', text='estado',
                      title='Correlação: Ticket Médio vs. Avaliação por Estado',
                      labels={'ticket_medio': 'Ticket Médio (R$)', 'avaliacao_media': 'Avaliação Média'},
                      template='plotly_white',
                      size='ticket_medio')
    fig3.update_traces(textposition='top center', marker=dict(color='#ff7f0e', line=dict(width=1, color='DarkSlateGrey')))
    fig3.write_image('Graficos/grafico_3_dispersao.png', width=1200, height=600)
    print("✅ Gráfico 3 salvo: Graficos/grafico_3_dispersao.png")
else:
    print("⚠️  Gráfico 3: sem dados")

# ============================================================================
# Gráfico 4: Dashboard / Composição
# ============================================================================
if not df1.empty and not df2.empty and not df3.empty:
    dashboard = make_subplots(
        rows=2, cols=2,
        subplot_titles=(
            'Evolução de Vendas', 
            'Top 10 Produtos',
            'Ticket Médio vs. Avaliação por Estado'
        ),
        specs=[[{"type": "xy"}, {"type": "xy"}],
               [{"type": "xy", "colspan": 2}, None]]
    )

    # Adiciona os traces dos gráficos anteriores à matriz do painel
    for trace in fig1.data:
        dashboard.add_trace(trace, row=1, col=1)
    for trace in fig2.data:
        dashboard.add_trace(trace, row=1, col=2)
    for trace in fig3.data:
        dashboard.add_trace(trace, row=2, col=1)

    dashboard.update_layout(
        title_text="Olist E-Commerce - Painel Executivo Analítico de Vendas",
        template='plotly_white',
        showlegend=False,
        height=900,
        width=1200
    )
    
    dashboard.write_html('Graficos/dashboard.html')
    print("✅ Gráfico 4 salvo: Graficos/dashboard.html")
else:
    print("⚠️  Gráfico 4: sem dados para compor o dashboard")

conn.close()

print("\n" + "=" * 60)
print("✅ Processo concluído! Verifique os arquivos na pasta Graficos/")
print("=" * 60)
print("\n📌 Gráficos gerados:")
print("   1. Evolução de Vendas (Linha)")
print("   2. Top 10 Produtos (Barras)")
print("   3. Correlação Ticket Médio vs Avaliação (Dispersão)")
print("   4. Painel Geral / Composição (Dashboard HTML)")
print("=" * 60)