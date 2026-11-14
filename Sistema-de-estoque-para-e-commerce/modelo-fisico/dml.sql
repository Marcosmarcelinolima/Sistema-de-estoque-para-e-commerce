/* =====================================================================
   02_dml.sql : carga de dados (>= 20 linhas por tabela)
   Executar DEPOIS do 01_ddl.sql (Alt + X no DBeaver).
   Nos dados repetitivos usamos generate_series(1, N), que gera 1..N.
   ===================================================================== */
SET search_path TO estoque;

-- categoria (20)
INSERT INTO categoria (nm_categoria) VALUES
('Eletronicos'),('Celulares'),('Notebooks'),('Games'),('Eletrodomesticos'),
('Moveis'),('Decoracao'),('Livros'),('Papelaria'),('Moda Masculina'),
('Moda Feminina'),('Calcados'),('Esportes'),('Beleza'),('Perfumaria'),
('Brinquedos'),('Pet Shop'),('Ferramentas'),('Automotivo'),('Software');

-- marca (20)
INSERT INTO marca (nm_marca) VALUES
('Samsung'),('Apple'),('Dell'),('Lenovo'),('Sony'),
('LG'),('Philips'),('Nike'),('Adidas'),('Puma'),
('Mondial'),('Britania'),('Electrolux'),('Tramontina'),('Faber-Castell'),
('Bic'),('Natura'),('Boticario'),('Hasbro'),('Intelbras');

-- deposito (20)
INSERT INTO deposito (nm_deposito, nm_cidade, sg_uf)
SELECT 'Deposito ' || LPAD(i::text, 2, '0'),
       (ARRAY['Criciuma', 'Sao Paulo', 'Rio de Janeiro', 'Belo Horizonte', 'Curitiba'])[i % 5 + 1],
       (ARRAY['SC', 'SP', 'RJ', 'MG', 'PR'])[i % 5 + 1]
FROM generate_series(1, 20) AS i
ORDER BY i;

-- fornecedor (20)
INSERT INTO fornecedor (nm_fornecedor, nr_cnpj, ds_email, nr_telefone)
SELECT 'Fornecedor ' || LPAD(i::text, 2, '0'),
       LPAD(i::text, 8, '0') || '000199',
       'contato' || i || '@fornecedor.com',
       '4899999' || LPAD(i::text, 4, '0')
FROM generate_series(1, 20) AS i
ORDER BY i;

-- produto (40): 1..20 fisicos, 21..40 digitais
INSERT INTO produto (cd_categoria, cd_marca, nm_produto, vl_preco, tp_produto)
SELECT ((i - 1) % 20) + 1,
       ((i - 1) % 20) + 1,
       CASE WHEN i <= 20 THEN 'Produto fisico ' ELSE 'Produto digital ' END || LPAD(i::text, 2, '0'),
       (19.90 + i * 7.5)::numeric(10,2),
       CASE WHEN i <= 20 THEN 'F' ELSE 'D' END
FROM generate_series(1, 40) AS i
ORDER BY i;

-- produto_fisico (20): produtos 1..20
INSERT INTO produto_fisico (cd_produto, vl_peso_kg, vl_altura_cm, vl_largura_cm, vl_comprimento_cm, is_fragil)
SELECT i,
       (0.2 + i * 0.15)::numeric(6,3),
       (5 + i * 1.5)::numeric(5,1),
       (10 + i)::numeric(5,1),
       (15 + i * 2)::numeric(5,1),
       (i % 3 = 0)
FROM generate_series(1, 20) AS i;

-- produto_digital (20): produtos 21..40
INSERT INTO produto_digital (cd_produto, ds_url_download, vl_tamanho_mb, qt_max_downloads)
SELECT i + 20,
       'https://loja.exemplo.com/download/' || (i + 20),
       (10 + i * 12.5)::numeric(8,2),
       3 + i % 3
FROM generate_series(1, 20) AS i;

-- produto_fornecedor (30)
INSERT INTO produto_fornecedor (cd_produto, cd_fornecedor, vl_custo, qt_prazo_dias)
SELECT i,
       ((i - 1) % 20) + 1,
       ((19.90 + i * 7.5) * 0.6)::numeric(10,2),
       3 + i % 10
FROM generate_series(1, 30) AS i;

-- estoque (40): cada produto fisico em 2 depositos
INSERT INTO estoque (cd_produto, cd_deposito, qt_estoque, qt_minima)
SELECT i, i, 100 + i * 5, 20 FROM generate_series(1, 20) AS i
UNION ALL
SELECT i, (i % 20) + 1, 80 + i * 3, 20 FROM generate_series(1, 20) AS i;

-- cliente (25)
INSERT INTO cliente (nm_cliente, ds_email, nr_cpf, dt_cadastro)
SELECT 'Cliente ' || LPAD(i::text, 2, '0'),
       'cliente' || i || '@email.com',
       (12345678900 + i)::text,
       CURRENT_DATE - i * 10
FROM generate_series(1, 25) AS i
ORDER BY i;

-- pedido (30) - vl_total e calculado depois pela function
INSERT INTO pedido (cd_cliente, cd_deposito, tp_status, dt_pedido)
SELECT ((i - 1) % 25) + 1,
       ((i - 1) % 20) + 1,
       (i % 4) + 1,
       LOCALTIMESTAMP(0) - i * INTERVAL '1 day'
FROM generate_series(1, 30) AS i
ORDER BY i;

-- item_pedido (40): apenas produtos fisicos (1..20)
INSERT INTO item_pedido (cd_pedido, cd_produto, qt_item, vl_unitario)
SELECT ((n.i - 1) % 30) + 1,
       p.cd_produto,
       1 + n.i % 3,
       p.vl_preco
FROM generate_series(1, 40) AS n(i)
JOIN produto p ON p.cd_produto = ((n.i - 1) % 20) + 1;

UPDATE pedido SET vl_total = fn_total_pedido(cd_pedido);

-- movimentacao_estoque (40): o TRIGGER atualiza o saldo de estoque
INSERT INTO movimentacao_estoque (cd_produto, cd_deposito, tp_movimentacao, qt_movimentada, dt_movimentacao)
SELECT i, i, 'E', 10 + i, LOCALTIMESTAMP(0) - i * INTERVAL '1 day' FROM generate_series(1, 20) AS i
UNION ALL
SELECT i, i, 'S', 5, LOCALTIMESTAMP(0) - i * INTERVAL '1 hour' FROM generate_series(1, 20) AS i;

-- =====================================================================
-- TESTE da STORED PROCEDURE + FUNCTION + TRIGGER
-- =====================================================================
SELECT 'ANTES' AS momento, qt_estoque FROM estoque WHERE cd_produto = 2 AND cd_deposito = 2;
SELECT 'ANTES' AS momento, vl_total FROM pedido WHERE cd_pedido = 1;

CALL sp_registrar_venda(1, 2, 2, 2);   -- pedido 1, produto 2, deposito 2, quantidade 2

SELECT 'DEPOIS' AS momento, qt_estoque FROM estoque WHERE cd_produto = 2 AND cd_deposito = 2;   -- 2 unidades a menos
SELECT 'DEPOIS' AS momento, vl_total FROM pedido WHERE cd_pedido = 1;                           -- total recalculado
SELECT fn_total_pedido(1) AS total_pelo_function;

-- contagem de linhas por tabela (todas >= 20)
SELECT 'categoria' AS tabela, COUNT(*) AS linhas FROM categoria UNION ALL
SELECT 'marca', COUNT(*) FROM marca UNION ALL
SELECT 'produto', COUNT(*) FROM produto UNION ALL
SELECT 'produto_fisico', COUNT(*) FROM produto_fisico UNION ALL
SELECT 'produto_digital', COUNT(*) FROM produto_digital UNION ALL
SELECT 'fornecedor', COUNT(*) FROM fornecedor UNION ALL
SELECT 'produto_fornecedor', COUNT(*) FROM produto_fornecedor UNION ALL
SELECT 'deposito', COUNT(*) FROM deposito UNION ALL
SELECT 'estoque', COUNT(*) FROM estoque UNION ALL
SELECT 'cliente', COUNT(*) FROM cliente UNION ALL
SELECT 'pedido', COUNT(*) FROM pedido UNION ALL
SELECT 'item_pedido', COUNT(*) FROM item_pedido UNION ALL
SELECT 'movimentacao_estoque', COUNT(*) FROM movimentacao_estoque;
