/* =====================================================================
   03_consultas.sql : perguntas de negocio e o indice que cada uma usa
   (criados em 01_ddl.sql)
   ===================================================================== */
SET search_path TO estoque;

-- Q1: Quais produtos existem na categoria 'Games' e quanto custam?
-- Indice: ix_produto_cd_categoria (produto.cd_categoria) | uq_categoria_nm (categoria.nm_categoria)
SELECT p.cd_produto, p.nm_produto, p.vl_preco
FROM produto p
JOIN categoria c ON c.cd_categoria = p.cd_categoria
WHERE c.nm_categoria = 'Games';

-- Q2: Quais produtos estao com estoque baixo (menos de 120 unidades) e em qual deposito?
-- Indice: ix_estoque_qt_estoque (estoque.qt_estoque)
SELECT p.nm_produto, d.nm_deposito, e.qt_estoque, e.qt_minima
FROM estoque e
JOIN produto p ON p.cd_produto = e.cd_produto
JOIN deposito d ON d.cd_deposito = e.cd_deposito
WHERE e.qt_estoque < 120
ORDER BY e.qt_estoque;

-- Q3: Quanto cada cliente ja gastou (pedidos nao cancelados)?
-- Indice: ix_pedido_cd_cliente (pedido.cd_cliente) INCLUDE vl_total
SELECT c.nm_cliente, COUNT(*) AS qt_pedidos, SUM(p.vl_total) AS vl_gasto
FROM pedido p
JOIN cliente c ON c.cd_cliente = p.cd_cliente
WHERE p.tp_status <> 4
GROUP BY c.nm_cliente
ORDER BY vl_gasto DESC;

-- Q4: Quais sao os 5 produtos mais vendidos?
-- Indice: ix_item_pedido_cd_produto (item_pedido.cd_produto) INCLUDE qt_item
SELECT p.nm_produto, SUM(i.qt_item) AS qt_vendida
FROM item_pedido i
JOIN produto p ON p.cd_produto = i.cd_produto
GROUP BY p.nm_produto
ORDER BY qt_vendida DESC
LIMIT 5;

-- Q5: Quantos pedidos e qual o faturamento por status nos ultimos 15 dias?
-- Indice: ix_pedido_dt_pedido (pedido.dt_pedido) INCLUDE tp_status, vl_total
SELECT tp_status, COUNT(*) AS qt_pedidos, SUM(vl_total) AS vl_faturado
FROM pedido
WHERE dt_pedido >= LOCALTIMESTAMP - INTERVAL '15 days'
GROUP BY tp_status;

-- Q6: Quais produtos o 'Fornecedor 05' fornece, a que custo e com qual prazo?
-- Indice: ix_produto_fornecedor_cd_fornecedor (produto_fornecedor.cd_fornecedor)
SELECT p.nm_produto, pf.vl_custo, pf.qt_prazo_dias
FROM produto_fornecedor pf
JOIN produto p ON p.cd_produto = pf.cd_produto
WHERE pf.cd_fornecedor = 5;

-- Q7: Qual o historico de entradas e saidas do produto 2 nos ultimos 30 dias?
-- Indice: ix_movimentacao_produto_dt (movimentacao_estoque.cd_produto, dt_movimentacao)
SELECT m.dt_movimentacao, m.tp_movimentacao, m.qt_movimentada, d.nm_deposito
FROM movimentacao_estoque m
JOIN deposito d ON d.cd_deposito = m.cd_deposito
WHERE m.cd_produto = 2
  AND m.dt_movimentacao >= LOCALTIMESTAMP - INTERVAL '30 days'
ORDER BY m.dt_movimentacao;

-- =====================================================================
-- COMPROVAR O USO DOS INDICES
-- Com tabelas pequenas o PostgreSQL prefere ler a tabela inteira (Seq Scan).
-- Para o plano mostrar o indice, desligamos o Seq Scan so nesta sessao.
-- Procure "Index Scan" / "Index Only Scan" / "Bitmap Index Scan" no resultado.
-- =====================================================================
SET enable_seqscan = off;

EXPLAIN SELECT * FROM estoque WHERE qt_estoque < 120;                                -- Q2
EXPLAIN SELECT cd_cliente, vl_total FROM pedido WHERE cd_cliente = 3;                -- Q3
EXPLAIN SELECT cd_produto, qt_item FROM item_pedido WHERE cd_produto = 5;            -- Q4
EXPLAIN SELECT tp_status, vl_total FROM pedido WHERE dt_pedido >= LOCALTIMESTAMP - INTERVAL '15 days';   -- Q5
EXPLAIN SELECT * FROM produto_fornecedor WHERE cd_fornecedor = 5;                    -- Q6
EXPLAIN SELECT * FROM movimentacao_estoque WHERE cd_produto = 2 AND dt_movimentacao >= LOCALTIMESTAMP - INTERVAL '30 days';  -- Q7

RESET enable_seqscan;
