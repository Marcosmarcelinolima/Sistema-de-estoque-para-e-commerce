
/*
=========================================================
1. PROJEÇÃO DE ESTOQUE COM BASE NO HISTÓRICO DE VENDAS
=========================================================

Solicitação do gerente:

"Precisamos analisar se o estoque atual será suficiente
para atender à demanda de um determinado período.
Compare o saldo disponível com a quantidade de produtos
vendidos no mesmo período do ano anterior, identificando
antecipadamente a necessidade de reposição."

Resultado:
- Nome do produto.
- Nome do depósito.
- Quantidade disponível.
- Quantidade vendida no período anterior.
- Saldo projetado.
- Indicador de necessidade de reposição.

Regra:
Saldo projetado = Estoque atual - Vendas do período anterior.

Tabelas:
produto, estoque, deposito, pedido e item_pedido.

OBS: dt_pedido é provisório e deve ser confirmado.
*/


/*
1. PROJEÇÃO DE ESTOQUE COM BASE NO HISTÓRICO DE VENDAS

Compare o estoque atual com a quantidade vendida
no mesmo período do ano anterior.
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
FROM estoque.produto p
INNER JOIN estoque.estoque e
    ON p.cd_produto = e.cd_produto
INNER JOIN estoque.deposito d
    ON e.cd_deposito = d.cd_deposito
LEFT JOIN (
    SELECT
        ip.cd_produto,
        SUM(ip.qt_item) AS quantidade_vendida
    FROM estoque.pedido ped
    INNER JOIN estoque.item_pedido ip
        ON ped.cd_pedido = ip.cd_pedido
    WHERE ped.tp_status = 2
      AND ped.dt_pedido >= DATE '2024-01-01'
      AND ped.dt_pedido < DATE '2024-02-01'
    GROUP BY ip.cd_produto
) v ON p.cd_produto = v.cd_produto
ORDER BY saldo_projetado ASC;


/*
=========================================================
2. ANÁLISE DE FATURAMENTO POR CLIENTE E REGIÃO
=========================================================

Solicitação do gerente:

"O setor comercial deseja identificar os clientes que
mais geraram receita para a empresa. Apresente o total
gasto por cada cliente, considerando somente os pedidos
com status pago, incluindo sua localização para auxiliar
na análise comercial por região."

Resultado:
- Nome do cliente.
- Cidade.
- Estado.
- Quantidade de pedidos pagos.
- Valor total gasto.

Tabelas:
cliente, pedido e item_pedido.

OBS: confirmar os nomes das colunas de cidade e estado.
*/

SELECT
    c.nm_cliente AS nome_cliente,
    c.nm_cidade AS cidade,
    c.sg_estado AS estado,
    COUNT(DISTINCT p.cd_pedido) AS quantidade_pedidos_pagos,
    SUM(ip.qt_item * ip.vl_unitario) AS valor_total_gasto
FROM estoque.cliente c
INNER JOIN estoque.pedido p
    ON c.cd_cliente = p.cd_cliente
INNER JOIN estoque.item_pedido ip
    ON p.cd_pedido = ip.cd_pedido
WHERE p.tp_status = 2
GROUP BY
    c.cd_cliente,
    c.nm_cliente,
    c.nm_cidade,
    c.sg_estado
ORDER BY valor_total_gasto DESC;


/*
=========================================================
3. ANÁLISE DE PRODUTOS POR CURVA ABC
=========================================================

Solicitação do gerente:

"A diretoria deseja identificar quais produtos possuem
maior participação no faturamento da empresa.
Gere um relatório utilizando a Curva ABC, permitindo
identificar os produtos mais relevantes financeiramente
e auxiliar no planejamento de compras e controle de estoque."

Resultado:
- Nome do produto.
- Categoria.
- Marca.
- Quantidade total vendida.
- Valor total vendido.
- Percentual de participação.
- Classificação ABC.

Regras:
A: até 80% do faturamento acumulado.
B: acima de 80% até 95%.
C: acima de 95%.

Tabelas:
produto, categoria, marca, item_pedido e pedido.
*/

WITH vendas_produtos AS (
    SELECT
        p.cd_produto,
        p.nm_produto,
        c.nm_categoria,
        m.nm_marca,
        SUM(ip.qt_item) AS quantidade_total_vendida,
        SUM(ip.qt_item * ip.vl_unitario) AS valor_total_vendido
    FROM estoque.produto p
    INNER JOIN estoque.categoria c
        ON p.cd_categoria = c.cd_categoria
    INNER JOIN estoque.marca m
        ON p.cd_marca = m.cd_marca
    INNER JOIN estoque.item_pedido ip
        ON p.cd_produto = ip.cd_produto
    INNER JOIN estoque.pedido ped
        ON ip.cd_pedido = ped.cd_pedido
    WHERE ped.tp_status = 2
    GROUP BY
        p.cd_produto,
        p.nm_produto,
        c.nm_categoria,
        m.nm_marca
),
participacao AS (
    SELECT
        *,
        ROUND(
            valor_total_vendido * 100.0 /
            NULLIF(SUM(valor_total_vendido) OVER (), 0),
            2
        ) AS percentual_participacao,
        SUM(valor_total_vendido) OVER (
            ORDER BY valor_total_vendido DESC, cd_produto
            ROWS BETWEEN UNBOUNDED PRECEDING
            AND CURRENT ROW
        ) * 100.0 /
        NULLIF(SUM(valor_total_vendido) OVER (), 0)
        AS percentual_acumulado
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
=========================================================
4. CÁLCULO DE MARGEM DE LUCRO E MARKUP
=========================================================

Solicitação do gerente:

"O setor financeiro precisa consultar a margem de lucro
dos produtos com base no preço de venda e no custo médio
informado pelos fornecedores.

Além disso, deseja calcular o Markup considerando
despesas variáveis, despesas fixas e margem desejada."

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

Quando houver mais de um fornecedor, utilizar
a média dos custos.
*/

CREATE OR REPLACE FUNCTION estoque.fn_margem_markup(
    p_cd_produto INT,
    p_dv NUMERIC(10,2),
    p_df NUMERIC(10,2),
    p_ml NUMERIC(10,2)
)
RETURNS TABLE (
    preco_venda NUMERIC(10,2),
    custo_medio NUMERIC(10,2),
    margem_lucro NUMERIC(10,2),
    markup_divisor NUMERIC(10,2)
)
LANGUAGE plpgsql
AS $$
BEGIN

    RETURN QUERY
    SELECT
        p.vl_preco::NUMERIC(10,2),
        AVG(pf.vl_custo)::NUMERIC(10,2),
        ROUND(
            ((p.vl_preco - AVG(pf.vl_custo))
            / NULLIF(p.vl_preco, 0)) * 100,
            2
        )::NUMERIC(10,2),
        ROUND(
            100.0 /
            NULLIF(100 - (p_dv + p_df + p_ml), 0),
            2
        )::NUMERIC(10,2)
    FROM estoque.produto p
    INNER JOIN estoque.produto_fornecedor pf
        ON p.cd_produto = pf.cd_produto
    WHERE p.cd_produto = p_cd_produto
    GROUP BY p.vl_preco;

END;
$$;


-- Teste da função
SELECT *
FROM estoque.fn_margem_markup(2, 10, 20, 40);


/*
=========================================================
5. REGISTRO DE REPOSIÇÃO DE ESTOQUE
=========================================================

Solicitação do gerente:

"Quando uma mercadoria chegar ao depósito, o funcionário
precisa registrar a entrada no sistema.
Desenvolva uma procedure que receba o código do produto,
o código do depósito e a quantidade recebida, registrando
automaticamente essa movimentação."

Regras:
- A quantidade recebida deve ser maior que zero.
- O produto precisa existir naquele depósito.
- A entrada deve ser registrada no histórico.
- O saldo deve ser atualizado automaticamente
  pelo trigger existente.

Tabelas:
estoque e movimentacao_estoque.
*/

CREATE OR REPLACE PROCEDURE estoque.sp_registrar_reposicao(
    p_cd_produto INT,
    p_cd_deposito SMALLINT,
    p_qt_recebida INT
)
LANGUAGE plpgsql
AS $$
BEGIN

    IF p_qt_recebida IS NULL OR p_qt_recebida <= 0 THEN
        RAISE EXCEPTION
            'A quantidade recebida deve ser maior que zero.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM estoque.estoque
        WHERE cd_produto = p_cd_produto
          AND cd_deposito = p_cd_deposito
    ) THEN
        RAISE EXCEPTION
            'Produto não cadastrado neste depósito.';
    END IF;

    INSERT INTO estoque.movimentacao_estoque (
        cd_produto,
        cd_deposito,
        tp_movimentacao,
        qt_movimentada
    )
    VALUES (
        p_cd_produto,
        p_cd_deposito,
        'E',
        p_qt_recebida
    );

    RAISE NOTICE 'Reposição registrada com sucesso!';

END;
$$;


-- Teste: saldo antes
SELECT cd_produto, cd_deposito, qt_estoque
FROM estoque.estoque
WHERE cd_produto = 1 AND cd_deposito = 1;

-- Executar reposição
CALL estoque.sp_registrar_reposicao(1, 1, 50);

-- Teste: saldo depois
SELECT cd_produto, cd_deposito, qt_estoque
FROM estoque.estoque
WHERE cd_produto = 1 AND cd_deposito = 1;



/*
=========================================================
6. BLOQUEIO DE VENDA DE PRODUTOS INATIVOS OU
   COM ESTOQUE INSUFICIENTE
=========================================================

Solicitação do gerente:

"A empresa identificou que produtos desativados ou que
não possuem quantidade disponível suficiente ainda podem
ser adicionados aos pedidos por operações realizadas
diretamente no banco. Desenvolva um trigger que impeça
a inclusão de itens em pedidos quando o produto estiver
inativo ou quando a quantidade solicitada comprometer
o estoque mínimo definido para o depósito."

Regras de negócio:

- Verificar o campo is_ativo da tabela produto.
- Se estiver FALSE, impedir a inserção.
- Retornar mensagem informando que o produto está inativo.
- Se estiver ativo, verificar a disponibilidade do estoque.
- Calcular a quantidade restante:
  Quantidade restante = Estoque atual - Quantidade solicitada.
- Se a quantidade restante for maior ou igual a qt_minima,
  permitir a inclusão.
- Caso contrário, impedir a operação e informar que
  o estoque é insuficiente para preservar o mínimo.

Tabelas:
produto, item_pedido e estoque.

Trigger:
estoque.tr_bloquear_produto_inativo.
*/


-- Adicionar o código do depósito ao item do pedido,
-- caso a coluna ainda não exista.
ALTER TABLE estoque.item_pedido
ADD COLUMN IF NOT EXISTS cd_deposito SMALLINT;


-- Criar função da trigger
CREATE OR REPLACE FUNCTION estoque.fn_bloquear_produto_inativo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_ativo BOOLEAN;
    v_estoque INTEGER;
    v_minima INTEGER;
BEGIN

    -- Verificar se o produto está ativo
    SELECT is_ativo
    INTO v_ativo
    FROM estoque.produto
    WHERE cd_produto = NEW.cd_produto;

    IF v_ativo IS DISTINCT FROM TRUE THEN
        RAISE EXCEPTION
            'Não é permitido vender: o produto está inativo.';
    END IF;

    -- Consultar o estoque do produto no depósito informado
    SELECT qt_estoque, qt_minima
    INTO v_estoque, v_minima
    FROM estoque.estoque
    WHERE cd_produto = NEW.cd_produto
      AND cd_deposito = NEW.cd_deposito
    FOR UPDATE;

    -- Verificar se existe estoque cadastrado
    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Não existe estoque cadastrado para este produto neste depósito.';
    END IF;

    -- Verificar se a quantidade restante preserva o estoque mínimo
    IF v_estoque - NEW.qt_item < v_minima THEN
        RAISE EXCEPTION
            'Estoque insuficiente: a venda comprometeria o estoque mínimo do depósito.';
    END IF;

    RETURN NEW;

END;
$$;


-- Criar trigger
DROP TRIGGER IF EXISTS tr_bloquear_produto_inativo
ON estoque.item_pedido;

CREATE TRIGGER tr_bloquear_produto_inativo
BEFORE INSERT ON estoque.item_pedido
FOR EACH ROW
EXECUTE FUNCTION estoque.fn_bloquear_produto_inativo();


-- TESTE 1: verificar bloqueio de produto inativo

DO $$
BEGIN

    UPDATE estoque.produto
    SET is_ativo = FALSE
    WHERE cd_produto = 20;

    BEGIN

        INSERT INTO estoque.item_pedido (
            cd_pedido,
            cd_produto,
            qt_item,
            vl_unitario,
            cd_deposito
        )
        VALUES (22, 20, 2, 600.00, 1);

        RAISE NOTICE 'ERRO: o produto inativo foi inserido.';

    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Bloqueio realizado: %', SQLERRM;

    END;

    -- Reativar produto
    UPDATE estoque.produto
    SET is_ativo = TRUE
    WHERE cd_produto = 20;

END;
$$;


-- TESTE 2: verificar bloqueio por estoque insuficiente

DO $$
DECLARE
    v_quantidade INTEGER;
BEGIN

    SELECT qt_estoque - qt_minima + 1
    INTO v_quantidade
    FROM estoque.estoque
    WHERE cd_produto = 20
      AND cd_deposito = 1;

    BEGIN

        INSERT INTO estoque.item_pedido (
            cd_pedido,
            cd_produto,
            qt_item,
            vl_unitario,
            cd_deposito
        )
        VALUES (22, 20, v_quantidade, 600.00, 1);

        RAISE NOTICE 'ERRO: a venda comprometeu o estoque mínimo.';

    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Bloqueio realizado: %', SQLERRM;

    END;

END;
$$;


-- Consultar os itens do pedido
SELECT *
FROM estoque.item_pedido
WHERE cd_pedido = 22;

