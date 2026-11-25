/*
1 "Precisamos identificar quais produtos estão próximos de acabar para que o setor de compras possa providenciar a reposição.
Liste os produtos cujo estoque atual esteja abaixo ou igual à quantidade mínima definida para cada depósito."
*/

SELECT
    estp.nm_produto AS Nome_Produto,
    estd.nm_deposito AS Nome_estoque,
    est.qt_estoque AS Quantidade_atual,
    est.qt_minima AS Quantidade_minima
FROM estoque.produto estp
INNER JOIN estoque.estoque est
    ON estp.cd_produto = est.cd_produto
INNER JOIN estoque.deposito estd
    ON estd.cd_deposito = est.cd_deposito
WHERE est.qt_estoque <= est.qt_minima
ORDER BY estp.nm_produto, estd.nm_deposito;
GO


/*
2"O setor comercial deseja identificar os clientes que mais geraram receita para a empresa.
Apresente o total gasto por cada cliente, considerando somente os pedidos com status pago.
Ordene do cliente que mais gastou para o que menos gastou."

O resultado deve apresentar:
- Nome do cliente.
- Quantidade de pedidos pagos.
- Valor total gasto.
*/

SELECT
    c.nm_cliente AS Nome_Cliente,
    COUNT(p.cd_pedido) AS Quantidade_Pedidos_Pagos,
    SUM(p.vl_total) AS Valor_Total_Gasto
FROM estoque.cliente c
INNER JOIN estoque.pedido p
    ON c.cd_cliente = p.cd_cliente
WHERE p.tp_status = 2
GROUP BY
    c.cd_cliente,
    c.nm_cliente
ORDER BY Valor_Total_Gasto DESC;
GO


/*
3"A diretoria deseja descobrir quais produtos possuem maior saída.
Gere um relatório com os 5 produtos mais vendidos, considerando a soma das quantidades comercializadas em todos os pedidos."

O resultado deve apresentar:
- Nome do produto.
- Categoria.
- Marca.
- Quantidade total vendida.
*/

SELECT TOP 5
    p.nm_produto AS Nome_Produto,
    c.nm_categoria AS Categoria,
    m.nm_marca AS Marca,
    SUM(ip.qt_item) AS Quantidade_Total_Vendida
FROM estoque.produto p
INNER JOIN estoque.categoria c
    ON p.cd_categoria = c.cd_categoria
INNER JOIN estoque.marca m
    ON p.cd_marca = m.cd_marca
INNER JOIN estoque.item_pedido ip
    ON p.cd_produto = ip.cd_produto
GROUP BY
    p.cd_produto,
    p.nm_produto,
    c.nm_categoria,
    m.nm_marca
ORDER BY Quantidade_Total_Vendida DESC;
GO


/*
4 "O setor financeiro precisa consultar a margem de lucro de cada produto com base no preço de venda e no custo informado pelos fornecedores.
Desenvolva uma função que receba o código de um produto e retorne sua margem de lucro percentual."

Exemplo:
- Preço de venda: R$ 200,00.
- Custo do fornecedor: R$ 120,00.
- Lucro bruto: R$ 80,00.
- Margem sobre o preço de venda: 40%.

Tabelas envolvidas: produto e produto_fornecedor.
(Quando o produto tem mais de um fornecedor, usa-se a média dos custos.)
*/

CREATE OR ALTER FUNCTION estoque.fn_margem_lucro
(
    @cd_produto INT
)
RETURNS DECIMAL(10,2)
AS
BEGIN

    DECLARE @vl_preco  NUMERIC(10,2);
    DECLARE @vl_custo  NUMERIC(10,2);
    DECLARE @vl_margem DECIMAL(10,2);

    SELECT
        @vl_preco = p.vl_preco,
        @vl_custo = AVG(pf.vl_custo)
    FROM estoque.produto p
    INNER JOIN estoque.produto_fornecedor pf
        ON p.cd_produto = pf.cd_produto
    WHERE p.cd_produto = @cd_produto
    GROUP BY p.vl_preco;

    IF @vl_preco IS NULL OR @vl_custo IS NULL
        RETURN NULL;

    SET @vl_margem =
        ((@vl_preco - @vl_custo) / @vl_preco) * 100;

    RETURN @vl_margem;

END;
GO

-- Teste da função
SELECT
    nm_produto,
    vl_preco,
    estoque.fn_margem_lucro(cd_produto) AS Margem_Lucro
FROM estoque.produto
ORDER BY Margem_Lucro DESC;
GO


/*
5 "Quando uma mercadoria chegar ao depósito, o funcionário precisa registrar a entrada no sistema.
Desenvolva uma procedure que receba o código do produto, o código do depósito e a quantidade recebida, registrando automaticamente essa movimentação."

Regras de negócio:
- A quantidade recebida deve ser maior que zero.
- O produto precisa existir naquele depósito.
- A entrada deve ser registrada no histórico de movimentações.
- O saldo do estoque deve ser atualizado automaticamente pelo trigger existente.

Tabelas envolvidas: estoque e movimentacao_estoque.
*/

CREATE OR ALTER PROCEDURE estoque.sp_registrar_reposicao
(
    @cd_produto INT,
    @cd_deposito SMALLINT,
    @qt_recebida INT
)
AS
BEGIN

    SET NOCOUNT ON;

    IF @qt_recebida <= 0
    BEGIN
        THROW 50001, 'A quantidade recebida deve ser maior que zero.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM estoque.estoque
        WHERE cd_produto = @cd_produto
          AND cd_deposito = @cd_deposito
    )
    BEGIN
        THROW 50002, 'Produto nao cadastrado neste deposito.', 1;
    END;

    INSERT INTO estoque.movimentacao_estoque
    (
        cd_produto,
        cd_deposito,
        tp_movimentacao,
        qt_movimentada
    )
    VALUES
    (
        @cd_produto,
        @cd_deposito,
        'E',
        @qt_recebida
    );

    PRINT 'Reposicao registrada com sucesso!';

END;
GO

-- Teste da procedure: saldo antes
SELECT cd_produto, cd_deposito, qt_estoque
FROM estoque.estoque
WHERE cd_produto = 1 AND cd_deposito = 1;

EXEC estoque.sp_registrar_reposicao
    @cd_produto = 1,
    @cd_deposito = 1,
    @qt_recebida = 50;

-- saldo depois (deve ter aumentado 50)
SELECT cd_produto, cd_deposito, qt_estoque
FROM estoque.estoque
WHERE cd_produto = 1 AND cd_deposito = 1;

/*
6"A empresa identificou que produtos desativados ainda podem ser adicionados aos pedidos por operações realizadas diretamente no banco.
Desenvolva um trigger que impeça a inclusão de itens em pedidos quando o produto estiver marcado como inativo."

Regras de negócio:
- Verificar o campo is_ativo da tabela produto.
- Se estiver como FALSE, impedir a inserção.
- Retornar uma mensagem informando que o produto está inativo.
- Se estiver ativo, permitir normalmente.

Tabelas envolvidas: produto e item_pedido.

Trigger: estoque.tr_bloquear_produto_inativo (criado no DDL.sql).
*/

-- Teste: desativa o produto 20 e tenta vender no pedido 22
UPDATE estoque.produto
SET is_ativo = 0
WHERE cd_produto = 20;

BEGIN TRY
    INSERT INTO estoque.item_pedido
    (cd_pedido, cd_produto, qt_item, vl_unitario)
    VALUES
    (22, 
    20, 
    2, 
    600.00);

    PRINT 'Item inserido (nao deveria acontecer).';
END TRY
BEGIN CATCH
    PRINT 'Erro esperado: ' + ERROR_MESSAGE();
END CATCH;

-- Reativa o produto e repete: agora deve permitir
UPDATE estoque.produto
SET is_ativo = 1
WHERE cd_produto = 20;

INSERT INTO estoque.item_pedido
(cd_pedido, cd_produto, qt_item, vl_unitario)
VALUES
(22, 20, 2, 600.00);

SELECT * FROM estoque.item_pedido WHERE cd_pedido = 22;

-- Desfaz o item de teste e recalcula o total do pedido
DELETE FROM estoque.item_pedido WHERE cd_pedido = 22 AND cd_produto = 20;
UPDATE estoque.pedido
SET vl_total = estoque.fn_total_pedido(cd_pedido)
WHERE cd_pedido = 22;
GO


/*
7"Quando uma movimentação de estoque for registrada, o saldo disponível do produto no depósito deverá ser atualizado automaticamente."

Regras:
- Se o tipo de movimentação for E, adicionar a quantidade ao estoque.
- Se o tipo de movimentação for S, retirar a quantidade do estoque.
- Não permitir que o estoque fique negativo.

Tabelas envolvidas: movimentacao_estoque e estoque.

Trigger: estoque.tr_atualizar_estoque (criado no DDL.sql).
*/

-- Saldo antes
SELECT cd_produto, cd_deposito, qt_estoque
FROM estoque.estoque
WHERE cd_produto = 2 AND cd_deposito = 2;

-- Registrar entrada de 50 unidades
INSERT INTO estoque.movimentacao_estoque
(cd_produto, cd_deposito, tp_movimentacao, qt_movimentada)
VALUES
(2, 2, 'E', 50);

-- Saldo depois (+50)
SELECT cd_produto, cd_deposito, qt_estoque
FROM estoque.estoque
WHERE cd_produto = 2 AND cd_deposito = 2;