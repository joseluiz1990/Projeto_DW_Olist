# Projeto_DW_Olist
Projeto de Data Warehouse usando DuckDB e dataset Olist para avaliação de Banco e Armazém de Dados

# Data Warehouse E-Commerce Olist 📊🚚

Este repositório contém a implementação completa de um **Data Warehouse (DW)** utilizando a modelagem estrela (*Star Schema*) para análise das operações de vendas e logística do e-commerce **Olist**. Todo o pipeline de dados (Ingestão, Staging, OLTP e OLAP) foi construído utilizando **DuckDB** e **SQL**, complementado por scripts de visualização analítica em **Python**.

---

## 📂 Estrutura do Projeto

O projeto está organizado na seguinte estrutura de diretórios e arquivos:

```text
dw-olist/
├── data/
│   └── olist/                  # Arquivos .csv originais extraídos do Kaggle
├── Graficos/                   # Diretório de destino para os gráficos gerados (PNG/HTML)
├── scripts/
│   ├── 00_setup_duckdb.sql     # Criação do ambiente de Staging (Tabelas stg_)
│   ├── 01_oltp.sql             # Criação e normalização do ambiente relacional (Schema oltp)
│   ├── 02_dw_model.sql         # Criação das Dimensões e Fatos (Schema dw)
│   ├── 03_etl_load.sql         # Pipeline de Carga ETL e controle de histórico SCD Tipo 2
│   └── 05_perf.sql             # Scripts bônus de Otimização e Materialização (Performance)
├── demo.duckdb                 # Banco de dados embarcado DuckDB (Gerado após execução)
├── duckdb.exe                  # Executável do CLI do DuckDB (Windows)
├── gerar_graficos.py           # Script Python para geração dos 4 gráficos obrigatórios
└── README.md                   # Documentação do projeto
```

## 🛠️ Pré-requisitos 
Antes de iniciar a execução, certifique-se de ter os seguintes componentes configurados na sua máquina:

### 1. Baixar dataset brazilianecommmerce
Acesse o site e baixe o dataset para a pasta /data/olist

Kaggle: https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

### 2. Baixar dataset brazilian-ecommerce olist
Acesse o site e baixe o dataset para a pasta /data/olist

### 3. Verificar a Versão do Python
Abra o PowerShell e execute:
Verificar se o Python está instalado

PowerShell
python –version

Se abrir a Microsoft Store ao digitar python:
Vá em: Configurações → Aplicativos → Aliases de execução do aplicativo
Desative os aliases "python.exe" e "python3.exe"

**Atenção: Microsoft Store**
Se o Windows abrir a Store ao digitar "python", desative o alias em Configurações → Aplicativos → Aliases de execução.
Depois instale o Python pelo site oficial: python.org/downloads

### 4. Instalar o DuckDB CLI no Windows
- Colocar o executável duckdb.exe na pasta raiz do projeto.
- Testar o duckdb.exe local

PowerShell
.\duckdb.exe demo.duckdb -c "SELECT 'ok' AS status;"

- Se preferir instalar globalmente (via winget):

PowerShell
winget install DuckDB.cli 

- Verificar versão

PowerShell
duckdb –version

**Nota: duckdb.exe local vs. global**
Se o duckdb não estiver no PATH, use sempre .\duckdb.exe (com ponto e barra) para chamar o executável local da pasta do projeto.
O script run_all.ps1 detecta automaticamente qual usar.

### 5. Configurar a Política de Execução do PowerShell
- Liberar scripts para o seu usuário (execute uma única vez)
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
- Se o Windows reclamar de assinatura, desbloqueie os arquivos:

PowerShell
Unblock-File .\run_all.ps1

PowerShell
Unblock-File .\scripts\*.sql

- Alternativa temporária (sem alterar a política permanente):

powershell -ExecutionPolicy Bypass -File .\run_all.ps1

### 6. Criar o Ambiente Virtual Python
- Entrar na pasta do projeto

PowerShell
cd C:\data\dw-atividade-olist-sample

- Criar ambiente virtual

PowerShell
python -m venv .venv

- Ativar o ambiente (PowerShell)

PowerShell
.\.venv\Scripts\Activate.ps1

- Atualizar o pip e instalar as dependências

PowerShell
python -m pip install --upgrade pip

PowerShell
pip install --only-binary=:all: duckdb pandas plotly kaleido

- Verificar instalação

PowerShell
python -c "import duckdb, pandas, plotly; print('OK')"

**Nota:**
--only-binary=:all:

Este parâmetro instrui o pip a baixar apenas versões pré-compiladas (wheels), evitando tentativas de compilar o DuckDB localmente, o que poderia falhar por falta de compiladores C no Windows.

## 🚀 Passo a Passo para Execução do Pipeline
Abra o seu terminal (preferencialmente o PowerShell no Windows) na raiz do projeto (C:\Users\...\data\dw-atividade-olist-sample) e execute os passos na ordem cronológica abaixo:

### Passo 1: Ingestão e Carga da Camada de Staging
Este script realiza a leitura dos arquivos .csv brutos contidos na pasta data/Olist/ e os espelha para tabelas de staging temporárias de forma ultra rápida.

PowerShell
.\duckdb.exe demo.duckdb -c ".read scripts/00_setup_duckdb.sql"

### Passo 2: Construção da Camada Transacional (OLTP)
Lê as tabelas de staging, higieniza as nomenclaturas redundantes e tipa os dados estruturadamente no schema oltp.

PowerShell
.\duckdb.exe demo.duckdb -c ".read scripts/01_oltp.sql"

### Passo 3: Criação das Estruturas Multidimensionais do DW
Cria as tabelas físicas do modelo estrela (dim_date, dim_customer, dim_product, dim_seller, dim_geolocation e fact_sales) definindo as Chaves Primárias (PK) e Estrangeiras (FK).

PowerShell
.\duckdb.exe demo.duckdb -c ".read scripts/02_dw_model.sql"

### Passo 4: Execução do Pipeline ETL (Carga OLAP)
Popula o Data Warehouse aplicando regras de negócio essenciais, geração de chaves substitutas (Surrogate Keys) e tratamento de histórico usando Dimensões de Mudança Lenta (SCD Tipo 2).

PowerShell
.\duckdb.exe demo.duckdb -c ".read scripts/03_etl_load.sql"

### Passo 5: Execução do Script de Performance e Otimização (Bônus)
Cria uma tabela analítica agregada (Data Mart), gera índices secundários B-Tree e exibe o comparativo do plano físico (EXPLAIN) demonstrando uma redução drástica no volume de linhas escaneadas de mais de 118 mil linhas para pouco mais de 1.200 linhas.

PowerShell
.\duckdb.exe demo.duckdb -c ".read scripts/05_perf.sql"

### Executando tudo
Executa todos os 5 scripts do pipeline completo de uma só vez

PowerShell
.\run_all.ps1

## 📊 Geração dos Gráficos Analíticos
Com o banco de dados demo.duckdb totalmente carregado e otimizado através dos passos anteriores, execute o script Python para extrair as métricas e gerar os relatórios visuais obrigatórios:

PowerShell
python gerar_graficos.py

### Resultados Esperados da Execução:
O terminal exibirá um cabeçalho oficial com as estatísticas consolidadas do volume do dataset e logs de confirmação acompanhados de checkmarks (✅) para cada item gerado com sucesso.

Os seguintes arquivos de imagem e painéis serão criados de forma automática dentro do diretório /Graficos:

grafico_1_evolucao.png (Gráfico de Linha: Evolução Temporal de Faturamento)

grafico_2_top_produtos.png (Gráfico de Barras: Top 10 Categorias por Receita)

grafico_3_dispersao.png (Gráfico de Dispersão: Correlação entre Ticket Médio vs. Avaliação por Estado)

dashboard.html (Painel Executivo Analítico Interativo agrupando as visões em uma única composição de subplots)
