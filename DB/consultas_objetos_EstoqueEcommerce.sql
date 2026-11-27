/*
=====================================================================
1. PROJEÇÃO DE ESTOQUE COM BASE NO HISTÓRICO DE VENDAS
=====================================================================

Pergunta de negócio:

"Precisamos analisar se o estoque atual será suficiente para atender à demanda de um determinado período. 
Para isso, queremos comparar o saldo disponível com a quantidade de produtos vendidos no mesmo período do ano anterior, 
identificando antecipadamente a necessidade de reposição."

O resultado deve apresentar:

Nome do produto.
Nome do depósito.
Quantidade disponível em estoque.
Quantidade vendida no mesmo período do ano anterior.
Projeção de saldo após a demanda estimada.
Indicador de necessidade de reposição.
Regra de negócio:

Projeção de estoque = Saldo disponível - Quantidade vendida no mesmo período do ano anterior.

Caso o saldo projetado seja inferior à quantidade mínima definida para o estoque, o sistema deverá indicar a necessidade de reposição.

Tabelas envolvidas: produto, estoque, depósito, pedido e item_pedido.
*/

SELECT
    p.nm_produto AS produto,
    d.nm_deposito AS deposito,
    e.qt_estoque AS estoque_atual,
    COALESCE(v.quantidade_vendida, 0) AS quantidade_vendida,
    e.qt_estoque - COALESCE(v.quantidade_vendida, 0) AS saldo_projetado,
    CASE
        WHEN e.qt_estoque - COALESCE(v.quantidade_vendida, 0) < e.qt_minima
            THEN 'Necessita reposicao'
        ELSE 'Estoque suficiente'
    END AS situacao
FROM estoque.produto AS p
INNER JOIN estoque.estoque AS e
    ON p.cd_produto = e.cd_produto
INNER JOIN estoque.deposito AS d
    ON e.cd_deposito = d.cd_deposito
LEFT JOIN (
    SELECT
        ip.cd_produto,
        SUM(ip.qt_item) AS quantidade_vendida
    FROM estoque.pedido AS ped
    INNER JOIN estoque.item_pedido AS ip
        ON ped.cd_pedido = ip.cd_pedido
    WHERE ped.tp_status = 2
      AND ped.dt_pedido >= '2024-01-01'
      AND ped.dt_pedido < '2024-02-01'
    GROUP BY ip.cd_produto
) AS v
    ON p.cd_produto = v.cd_produto
ORDER BY saldo_projetado ASC;


/*
=====================================================================
2. ANÁLISE DE FATURAMENTO POR CLIENTE E REGIÃO
=====================================================================

Pergunta de negócio:
"O setor comercial deseja identificar os clientes que mais geraram receita para a empresa, considerando somente os pedidos pagos. Além disso, queremos visualizar a localização dos clientes para facilitar a análise de desempenho comercial por região e auxiliar na definição de estratégias de atendimento."

O resultado deve apresentar:

Nome do cliente.
Cidade e estado.
Quantidade de pedidos pagos.
Valor total gasto.
Regra de negócio:

Considerar somente pedidos com status pago, agrupando os resultados por cliente e localização, ordenados do maior para o menor valor gasto.

Tabelas envolvidas: cliente e pedido.
*/

SELECT
    c.nm_cliente AS nome_cliente,
    d.nm_cidade AS cidade,
    d.sg_uf AS estado,
    COUNT(ped.cd_pedido) AS quantidade_pedidos_pagos,
    SUM(ped.vl_total) AS valor_total_gasto
FROM estoque.cliente AS c
INNER JOIN estoque.pedido AS ped
    ON c.cd_cliente = ped.cd_cliente
INNER JOIN estoque.deposito AS d
    ON ped.cd_deposito = d.cd_deposito
WHERE ped.tp_status = 2
GROUP BY
    c.cd_cliente,
    c.nm_cliente,
    d.cd_deposito,
    d.nm_cidade,
    d.sg_uf
ORDER BY valor_total_gasto DESC;


/*
=====================================================================
3. ANÁLISE DE PRODUTOS POR CURVA ABC
=====================================================================

Pergunta de negócio:
"A diretoria deseja identificar quais produtos possuem maior participação no faturamento da empresa. Para isso, precisamos de um relatório baseado na Curva ABC, permitindo identificar os produtos mais relevantes financeiramente e auxiliar no planejamento de compras e controle de estoque."

O resultado deve apresentar:

Nome do produto.
Categoria.
Marca.
Quantidade total vendida.
Valor total vendido.
Percentual de participação nas vendas.
Classificação ABC do produto.
Regra de negócio:

Calcular o faturamento de cada produto com base nas vendas realizadas e identificar seu percentual de participação em relação ao faturamento total.

A partir da participação acumulada, classificar os produtos nas categorias A, B e C, conforme os critérios de classificação definidos para a análise.

Tabelas envolvidas: produto, categoria, marca, item_pedido e pedido.
*/

;WITH vendas_produtos AS
(
    SELECT
        p.cd_produto,
        p.nm_produto,
        c.nm_categoria,
        m.nm_marca,
        SUM(ip.qt_item) AS quantidade_total_vendida,
        SUM(CAST(ip.qt_item AS DECIMAL(18, 2)) * ip.vl_unitario) AS valor_total_vendido
    FROM estoque.produto AS p
    INNER JOIN estoque.categoria AS c
        ON p.cd_categoria = c.cd_categoria
    INNER JOIN estoque.marca AS m
        ON p.cd_marca = m.cd_marca
    INNER JOIN estoque.item_pedido AS ip
        ON p.cd_produto = ip.cd_produto
    INNER JOIN estoque.pedido AS ped
        ON ip.cd_pedido = ped.cd_pedido
    WHERE ped.tp_status = 2
    GROUP BY
        p.cd_produto,
        p.nm_produto,
        c.nm_categoria,
        m.nm_marca
),
participacao AS
(
    SELECT
        cd_produto,
        nm_produto,
        nm_categoria,
        nm_marca,
        quantidade_total_vendida,
        valor_total_vendido,
        ROUND(
            valor_total_vendido * 100.0 /
            NULLIF(SUM(valor_total_vendido) OVER (), 0),
            2
        ) AS percentual_participacao,
        SUM(valor_total_vendido) OVER
        (
            ORDER BY valor_total_vendido DESC, cd_produto
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) * 100.0 /
        NULLIF(SUM(valor_total_vendido) OVER (), 0) AS percentual_acumulado
    FROM vendas_produtos
)
SELECT
    nm_produto AS nome_produto,
    nm_categoria AS categoria,
    nm_marca AS marca,
    quantidade_total_vendida,
    valor_total_vendido,
    percentual_participacao,
    ROUND(percentual_acumulado, 2) AS percentual_acumulado,
    CASE
        WHEN percentual_acumulado <= 80 THEN 'A'
        WHEN percentual_acumulado <= 95 THEN 'B'
        ELSE 'C'
    END AS classificacao_abc
FROM participacao
ORDER BY valor_total_vendido DESC;


/*
=====================================================================
4. CÁLCULO DE MARGEM DE LUCRO E MARKUP
=====================================================================

Objetivo:
Permitir consultar a margem de lucro de um produto com base no preço
de venda e no custo médio informado pelos fornecedores, além de
calcular o divisor de Markup.

Exemplo:
Preço de venda: R$ 200,00.
Custo médio: R$ 120,00.
Lucro bruto: R$ 80,00.
Margem: 40%.

Fórmulas:
Margem = ((Preço - Custo) / Preço) * 100.
Markup divisor = 100 / (100 - (DV + DF + ML)).

Tabelas:
produto e produto_fornecedor.

Quando houver mais de um fornecedor, utilizar a média dos custos.

NOTA:
Esta é uma função do SQL Server que retorna uma tabela.
*/

CREATE OR ALTER FUNCTION estoque.fn_margem_markup
(
    @p_cd_produto INT,
    @p_dv DECIMAL(10, 2),
    @p_df DECIMAL(10, 2),
    @p_ml DECIMAL(10, 2)
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        CAST(p.vl_preco AS DECIMAL(10, 2)) AS preco_venda,
        CAST(AVG(CAST(pf.vl_custo AS DECIMAL(18, 4))) AS DECIMAL(10, 2)) AS custo_medio,
        CAST
        (
            ROUND
            (
                (
                    (p.vl_preco - AVG(CAST(pf.vl_custo AS DECIMAL(18, 4))))
                    / NULLIF(p.vl_preco, 0)
                ) * 100,
                2
            ) AS DECIMAL(10, 2)
        ) AS margem_lucro,
        CAST
        (
            ROUND
            (
                100.0 / NULLIF(100.0 - (@p_dv + @p_df + @p_ml), 0),
                2
            ) AS DECIMAL(10, 2)
        ) AS markup_divisor
    FROM estoque.produto AS p
    INNER JOIN estoque.produto_fornecedor AS pf
        ON p.cd_produto = pf.cd_produto
    WHERE p.cd_produto = @p_cd_produto
    GROUP BY p.vl_preco
);
GO

-- Teste da função:
SELECT *
FROM estoque.fn_margem_markup(2, 10, 20, 40);
GO


/*
=====================================================================
5. Análise de necessidade de reposição de estoque - PROCEDURE
=====================================================================

"Quais produtos apresentam maior necessidade de reposição, considerando o estoque mínimo definido, o saldo atual e o histórico de movimentações?
Identifique os produtos que precisam de atenção para evitar falta de mercadorias nos depósitos."

Resultado esperado:
- Nome do produto.
- Nome do depósito.
- Quantidade atual em estoque.
- Estoque mínimo.
- Quantidade de entradas registradas.
- Quantidade de saídas registradas.
- Saldo de movimentações.
- Indicador de necessidade de reposição.

Regras de análise:
1. Identificar produtos cujo estoque atual esteja abaixo ou igual ao estoque mínimo.
2. Consultar o histórico de entradas e saídas.
3. Calcular o saldo de movimentações no período.
4. Identificar os produtos com maior necessidade de reposição.

Tabelas envolvidas:
- produto
- estoque
- deposito
- movimentacao_estoque
*/


CREATE OR ALTER PROCEDURE estoque.sp_analisar_reposicao
    @p_data_inicio DATE,
    @p_data_fim DATE
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.cd_produto,
        p.nm_produto AS produto,
        d.nm_deposito AS deposito,
        e.qt_estoque AS estoque_atual,
        e.qt_minima AS estoque_minimo,

        COALESCE(m.quantidade_entradas, 0) AS total_entradas,
        COALESCE(m.quantidade_saidas, 0) AS total_saidas,

        COALESCE(m.quantidade_entradas, 0)
        - COALESCE(m.quantidade_saidas, 0)
        AS saldo_movimentacoes,

        CASE
            WHEN e.qt_estoque <= e.qt_minima
                THEN 'Necessita reposicao'
            ELSE 'Estoque suficiente'
        END AS situacao

    FROM estoque.estoque AS e

    INNER JOIN estoque.produto AS p
        ON e.cd_produto = p.cd_produto

    INNER JOIN estoque.deposito AS d
        ON e.cd_deposito = d.cd_deposito

    LEFT JOIN
    (
        SELECT
            cd_produto,
            cd_deposito,

            SUM(
                CASE
                    WHEN tp_movimentacao = 'E'
                        THEN qt_movimentada
                    ELSE 0
                END
            ) AS quantidade_entradas,

            SUM(
                CASE
                    WHEN tp_movimentacao = 'S'
                        THEN qt_movimentada
                    ELSE 0
                END
            ) AS quantidade_saidas

        FROM estoque.movimentacao_estoque

        WHERE dt_movimentacao >= @p_data_inicio
          AND dt_movimentacao < DATEADD(DAY, 1, @p_data_fim)

        GROUP BY
            cd_produto,
            cd_deposito

    ) AS m
        ON e.cd_produto = m.cd_produto
       AND e.cd_deposito = m.cd_deposito

    ORDER BY
        CASE
            WHEN e.qt_estoque <= e.qt_minima THEN 0
            ELSE 1
        END,
        (e.qt_estoque - e.qt_minima) ASC;

END;
GO


--Como execultar

EXEC estoque.sp_analisar_reposicao
    @p_data_inicio = '2025-01-01',
    @p_data_fim = '2025-12-31';

/*


=====================================================================
6. Análise de faturamento por categoria de produtos - Função
=====================================================================

FUNCTION
Solicitação do gerente:

"A diretoria deseja identificar quais categorias de produtos apresentam melhor desempenho comercial. 
Desenvolva uma função que permita consultar o faturamento por categoria em determinado período, apresentando a quantidade de produtos vendidos, o número de pedidos realizados e o ticket médio, 
auxiliando na identificação das categorias mais relevantes para o negócio."

Resultado esperado:
- Nome da categoria.
- Quantidade total de produtos vendidos.
- Quantidade de pedidos realizados.
- Faturamento total da categoria.
- Ticket médio por pedido.
- Ordenação das categorias com maior faturamento.

Regras de negócio:
- Considerar somente pedidos com status pago (tp_status = 2).
- Filtrar os pedidos pelo período informado.
- Agrupar os resultados por categoria.
- Calcular o faturamento multiplicando a quantidade pelo valor unitário.
- Calcular o ticket médio dividindo o faturamento pela quantidade de pedidos da categoria.
Tabelas envolvidas: categoria, produto, item_pedido e pedido.
*/

CREATE OR ALTER FUNCTION estoque.fn_faturamento_categoria
(
    @p_data_inicio DATE,
    @p_data_fim DATE
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        c.nm_categoria AS categoria,

        SUM(ip.qt_item) AS quantidade_vendida,

        COUNT(DISTINCT ped.cd_pedido) AS quantidade_pedidos,

        SUM(ip.qt_item * ip.vl_unitario) AS faturamento_total,

        CAST(
            SUM(ip.qt_item * ip.vl_unitario) /
            NULLIF(COUNT(DISTINCT ped.cd_pedido), 0)
            AS DECIMAL(10,2)
        ) AS ticket_medio

    FROM estoque.categoria c

    INNER JOIN estoque.produto p
        ON c.cd_categoria = p.cd_categoria

    INNER JOIN estoque.item_pedido ip
        ON p.cd_produto = ip.cd_produto

    INNER JOIN estoque.pedido ped
        ON ip.cd_pedido = ped.cd_pedido

    WHERE ped.tp_status = 2
      AND ped.dt_pedido >= @p_data_inicio
      AND ped.dt_pedido < DATEADD(DAY, 1, @p_data_fim)

    GROUP BY
        c.cd_categoria,
        c.nm_categoria
);
GO

SELECT *
FROM estoque.fn_faturamento_categoria(
    '2026-11-27',
    '2026-11-27'
)
ORDER BY faturamento_total DESC;


/*
=====================================================================
Bloqueio de venda de produtos inativos ou com estoque insuficiente
TRIGGER
=====================================================================


Objetivo: impedir a venda de produtos inativos ou que deixem o estoque abaixo do mínimo permitido.

Regras:
- Verificar se o produto está ativo.
- Verificar se existe estoque cadastrado.
- Impedir a venda caso o estoque restante fique abaixo do mínimo.
Tabelas: produto, item_pedido e estoque.
*/


CREATE OR ALTER TRIGGER estoque.tr_bloquear_produto_inativo
ON estoque.item_pedido
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Verificar se o produto está ativo.
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN estoque.produto p
            ON p.cd_produto = i.cd_produto
        WHERE p.is_ativo = 0
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51001, 'Produto inativo. Venda não permitida.', 1;
    END;

    -- Verificar se o estoque é suficiente.
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN estoque.estoque e
            ON e.cd_produto = i.cd_produto
           AND e.cd_deposito = i.cd_deposito
        WHERE e.qt_estoque - i.qt_item < e.qt_minima
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 51002, 'Estoque insuficiente para realizar a venda.', 1;
    END;
END;
GO


/*
=====================================================================
TESTES DA TRIGGER
=====================================================================
*/

-- TESTE 1: Desativar o produto

UPDATE estoque.produto
SET is_ativo = 0
WHERE cd_produto = 20; -- Validar se esse codigo existe na hora da apresentação.

-- Tentar inserir no pedido
INSERT INTO estoque.item_pedido
(cd_pedido, cd_produto, qt_item, vl_unitario, cd_deposito)
VALUES (22, 20, 2, 600.00, 1);

-- TESTE 2: Testar estoque insuficiente

-- reativAR o produto:
UPDATE estoque.produto
SET is_ativo = 1
WHERE cd_produto = 20;

--Agora consulte o estoque:

SELECT qt_estoque, qt_minima
FROM estoque.estoque
WHERE cd_produto = 20
  AND cd_deposito = 1;

--Tente vender uma quantidade maior do que a disponível acima do mínimo:

INSERT INTO estoque.item_pedido
(cd_pedido, cd_produto, qt_item, vl_unitario, cd_deposito)
SELECT
    22,
    20,
    qt_estoque - qt_minima + 1,
    600.00,
    1
FROM estoque.estoque
WHERE cd_produto = 20
  AND cd_deposito = 1;
  
  
/*
=====================================================================
ÍNDICES PARA OTIMIZAÇÃO DAS PERGUNTAS DE NEGÓCIO
=====================================================================
*/

-- 1. PROJEÇÃO DE ESTOQUE COM BASE NO HISTÓRICO DE VENDAS

CREATE NONCLUSTERED INDEX IX_pedido_status_data
ON estoque.pedido (tp_status, dt_pedido)
INCLUDE (cd_pedido);

-- Facilita a busca de pedidos pagos dentro do período informado.


CREATE NONCLUSTERED INDEX IX_item_pedido_pedido_produto
ON estoque.item_pedido (cd_pedido, cd_produto)
INCLUDE (qt_item);

-- Otimiza a ligação entre pedidos e itens, permitindo consultar os produtos vendidos.


-- 2. FATURAMENTO POR CLIENTE E REGIÃO

CREATE NONCLUSTERED INDEX IX_pedido_cliente_status
ON estoque.pedido (cd_cliente, tp_status)
INCLUDE (cd_pedido);

-- Facilita a consulta dos pedidos pagos agrupados por cliente.


CREATE NONCLUSTERED INDEX IX_item_pedido_cd_pedido
ON estoque.item_pedido (cd_pedido)
INCLUDE (qt_item, vl_unitario);

-- Agiliza a busca dos itens de cada pedido e o cálculo do faturamento.


-- 3. ANÁLISE DE PRODUTOS POR CURVA ABC

CREATE NONCLUSTERED INDEX IX_item_pedido_produto_pedido
ON estoque.item_pedido (cd_produto, cd_pedido)
INCLUDE (qt_item, vl_unitario);

-- Facilita a consulta das vendas por produto e o cálculo do faturamento.


-- 4. CÁLCULO DE MARGEM DE LUCRO E MARKUP

CREATE NONCLUSTERED INDEX IX_produto_fornecedor_produto
ON estoque.produto_fornecedor (cd_produto)
INCLUDE (vl_custo);

-- Agiliza a busca dos custos dos fornecedores de cada produto.


-- 5. ANÁLISE DE NECESSIDADE DE REPOSIÇÃO

CREATE NONCLUSTERED INDEX IX_movimentacao_data_produto_deposito
ON estoque.movimentacao_estoque (dt_movimentacao, cd_produto, cd_deposito)
INCLUDE (tp_movimentacao, qt_movimentada);

-- Facilita a consulta das movimentações realizadas dentro do período informado.


-- 6. FATURAMENTO POR CATEGORIA DE PRODUTOS

CREATE NONCLUSTERED INDEX IX_produto_categoria
ON estoque.produto (cd_categoria, cd_produto);

-- Agiliza a busca dos produtos vinculados a cada categoria.


CREATE NONCLUSTERED INDEX IX_item_pedido_produto
ON estoque.item_pedido (cd_produto, cd_pedido)
INCLUDE (qt_item, vl_unitario);

-- Facilita a consulta dos itens vendidos por produto e o cálculo do faturamento por categoria.


-- TRIGGER: BLOQUEIO DE VENDA DE PRODUTOS INATIVOS OU COM ESTOQUE INSUFICIENTE

CREATE NONCLUSTERED INDEX IX_estoque_produto_deposito
ON estoque.estoque (cd_produto, cd_deposito)
INCLUDE (qt_estoque, qt_minima);

-- Agiliza a localização do estoque do produto no depósito para validar a quantidade disponível.
