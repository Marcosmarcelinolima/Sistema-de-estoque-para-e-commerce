-- =============================================
-- BANCO DE DADOS II - SISTEMA DE ESTOQUE
-- DML.sql - SQL SERVER / SSMS
-- Executar DEPOIS do DDL.sql
-- Dados variados: varios depositos por produto, clientes com varios
-- pedidos, pedidos com varios itens e status diferentes.
-- =============================================

-- =============================================
-- CATEGORIA (20)
-- =============================================
INSERT INTO estoque.categoria (nm_categoria) VALUES
('Eletronicos'),('Celulares'),('Notebooks'),('Games'),
('Eletrodomesticos'),('Moveis'),('Decoracao'),('Livros'),
('Papelaria'),('Moda Masculina'),('Moda Feminina'),('Calcados'),
('Esportes'),('Beleza'),('Perfumaria'),('Brinquedos'),
('Pet Shop'),('Ferramentas'),('Automotivo'),('Software');

-- =============================================
-- MARCA (20)
-- =============================================
INSERT INTO estoque.marca (nm_marca) VALUES
('Samsung'),('Apple'),('Dell'),('Lenovo'),('Sony'),
('LG'),('Philips'),('Nike'),('Adidas'),('Puma'),
('Mondial'),('Britania'),('Electrolux'),('Tramontina'),
('Faber Castell'),('Bic'),('Natura'),('Boticario'),
('Hasbro'),('Intelbras');

-- =============================================
-- DEPOSITO (20)
-- =============================================
INSERT INTO estoque.deposito (nm_deposito, nm_cidade, sg_uf)
SELECT
    'Deposito ' + CAST(n AS VARCHAR(2)),
    CASE (n % 5)
        WHEN 1 THEN 'Criciuma'
        WHEN 2 THEN 'Sao Paulo'
        WHEN 3 THEN 'Curitiba'
        WHEN 4 THEN 'Rio de Janeiro'
        ELSE 'Belo Horizonte'
    END,
    CASE (n % 5)
        WHEN 1 THEN 'SC'
        WHEN 2 THEN 'SP'
        WHEN 3 THEN 'PR'
        WHEN 4 THEN 'RJ'
        ELSE 'MG'
    END
FROM (VALUES
(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),
(11),(12),(13),(14),(15),(16),(17),(18),(19),(20)
) AS numeros(n);

-- =============================================
-- FORNECEDOR (20)
-- =============================================
INSERT INTO estoque.fornecedor
(nm_fornecedor, nr_cnpj, ds_email, nr_telefone)
SELECT
    'Fornecedor ' + CAST(n AS VARCHAR(2)),
    '000000' + RIGHT('0000' + CAST(n AS VARCHAR(4)), 4) + '0199',
    'fornecedor' + CAST(n AS VARCHAR(2)) + '@email.com',
    '4899999' + RIGHT('0000' + CAST(n AS VARCHAR(4)), 4)
FROM (VALUES
(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),
(11),(12),(13),(14),(15),(16),(17),(18),(19),(20)
) AS numeros(n);

-- =============================================
-- PRODUTO (40) - 20 fisicos (1-20) e 20 digitais (21-40)
-- (cd_categoria, cd_marca, nome, preco, tipo)
-- =============================================
INSERT INTO estoque.produto
(cd_categoria, cd_marca, nm_produto, vl_preco, tp_produto)
VALUES
-- fisicos
(2,1,'Smartphone Samsung',1500,'F'),
(2,2,'iPhone',4500,'F'),
(3,3,'Notebook Dell',3500,'F'),
(3,4,'Notebook Lenovo',2800,'F'),
(1,5,'Televisao Sony',2200,'F'),
(1,6,'Monitor LG',1200,'F'),
(1,7,'Fone Philips',150,'F'),
(12,8,'Tenis Nike',400,'F'),
(12,9,'Tenis Adidas',350,'F'),
(10,10,'Camisa Puma',180,'F'),
(5,11,'Liquidificador Mondial',130,'F'),
(5,12,'Ventilador Britania',200,'F'),
(5,13,'Geladeira Electrolux',2800,'F'),
(5,14,'Panela Tramontina',250,'F'),
(9,15,'Lapis Faber Castell',5,'F'),
(9,16,'Caneta Bic',3,'F'),
(15,17,'Perfume Natura',120,'F'),
(15,18,'Perfume Boticario',150,'F'),
(16,19,'Brinquedo Hasbro',90,'F'),
(1,20,'Camera Intelbras',600,'F'),
-- digitais
(20,1,'Windows Digital',299,'D'),
(20,2,'Antivirus Digital',99,'D'),
(20,3,'Curso de Informatica',150,'D'),
(4,4,'Jogo Digital',120,'D'),
(8,5,'Livro Digital',35,'D'),
(20,6,'Projeto Digital',80,'D'),
(20,7,'Editor de Imagens',200,'D'),
(13,8,'Curso de Esportes',100,'D'),
(20,9,'Planilha Financeira',25,'D'),
(10,10,'Curso de Moda',90,'D'),
(8,11,'Manual Digital',30,'D'),
(20,12,'Aplicativo de Vendas',250,'D'),
(20,13,'Software de Estoque',400,'D'),
(20,14,'Projeto de Design',180,'D'),
(8,15,'Apostila Digital',40,'D'),
(8,16,'Ebook de Estudos',25,'D'),
(14,17,'Curso de Beleza',110,'D'),
(8,18,'Catalogo Digital',50,'D'),
(4,19,'Jogo Infantil Digital',60,'D'),
(20,20,'Software de Seguranca',350,'D');

-- =============================================
-- PRODUTO FISICO (20)
-- =============================================
INSERT INTO estoque.produto_fisico
(cd_produto, vl_peso_kg, vl_altura_cm, vl_largura_cm,
 vl_comprimento_cm, is_fragil)
VALUES
(1,0.200,15,7,1,1),
(2,0.180,15,7,1,1),
(3,2.500,30,35,25,1),
(4,2.300,30,35,25,1),
(5,8.000,70,110,10,1),
(6,3.000,40,60,10,1),
(7,0.300,10,10,15,1),
(8,0.800,12,10,30,0),
(9,0.850,12,10,30,0),
(10,0.250,5,25,30,0),
(11,1.500,30,20,20,0),
(12,2.000,50,30,30,0),
(13,50.000,180,70,70,1),
(14,1.000,10,30,30,0),
(15,0.050,2,1,1,0),
(16,0.010,1,1,1,0),
(17,0.300,15,5,5,1),
(18,0.300,15,5,5,1),
(19,0.500,20,20,20,0),
(20,1.200,15,20,20,1);

-- =============================================
-- PRODUTO DIGITAL (20)
-- =============================================
INSERT INTO estoque.produto_digital
(cd_produto, ds_url_download, vl_tamanho_mb, qt_max_downloads)
VALUES
(21,'https://loja.com/21',100,3),
(22,'https://loja.com/22',50,3),
(23,'https://loja.com/23',200,5),
(24,'https://loja.com/24',150,3),
(25,'https://loja.com/25',30,4),
(26,'https://loja.com/26',80,3),
(27,'https://loja.com/27',250,5),
(28,'https://loja.com/28',120,3),
(29,'https://loja.com/29',20,4),
(30,'https://loja.com/30',90,3),
(31,'https://loja.com/31',40,3),
(32,'https://loja.com/32',300,5),
(33,'https://loja.com/33',400,3),
(34,'https://loja.com/34',180,4),
(35,'https://loja.com/35',60,3),
(36,'https://loja.com/36',25,3),
(37,'https://loja.com/37',110,4),
(38,'https://loja.com/38',50,3),
(39,'https://loja.com/39',70,5),
(40,'https://loja.com/40',350,3);

-- =============================================
-- PRODUTO_FORNECEDOR
-- Todos os produtos tem fornecedor; alguns fisicos tem 2 fornecedores
-- (a margem usa a media dos custos)
-- =============================================
INSERT INTO estoque.produto_fornecedor
(cd_produto, cd_fornecedor, vl_custo, qt_prazo_dias)
VALUES
-- fisicos (1 fornecedor cada)
(1,1,900,5),(2,2,3000,7),
(3,3,2500,10),(4,4,1900,8),
(5,5,1500,6),(6,6,800,5),
(7,7,90,3),(8,8,250,5),
(9,9,220,4),(10,10,100,5),
(11,11,80,3),(12,12,130,4),
(13,13,2000,10),(14,14,150,5),
(15,15,2,2),(16,16,1,2),
(17,17,70,4),(18,18,90,5),
(19,19,50,4),(20,20,400,7),
-- fisicos (segundo fornecedor)
(1,2,950,6),(2,1,3100,8),
(3,4,2450,9),(5,6,1550,7),
(8,9,260,6),(10,11,95,5),
(13,14,1950,12),(20,1,420,6),
-- digitais
(21,1,120,1),(22,2,30,1),(23,3,60,1),(24,4,50,1),
(25,5,10,1),(26,6,30,1),(27,7,90,1),(28,8,40,1),
(29,9,8,1),(30,10,35,1),(31,11,10,1),(32,12,100,1),
(33,13,150,1),(34,14,70,1),(35,15,15,1),(36,16,8,1),
(37,17,45,1),(38,18,20,1),(39,19,25,1),(40,20,150,1);

-- =============================================
-- ESTOQUE (60 = 3 depositos por produto fisico)
-- Mistura de saldos acima e abaixo do minimo
-- =============================================
-- Grupo 1: produto n no deposito n
INSERT INTO estoque.estoque
(cd_produto, cd_deposito, qt_estoque, qt_minima)
VALUES
(1,1,15,20),(2,2,90,20),
(3,3,80,20),(4,4,13,20),
(5,5,60,20),(6,6,50,20),
(7,7,40,20),(8,8,19,20),
(9,9,20,10),(10,10,100,20),
(11,11,90,20),(12,12,80,20),
(13,13,10,20),(14,14,60,20),
(15,15,50,20),(16,16,40,20),
(17,17,30,20),(18,18,20,10),
(19,19,100,20),(20,20,90,20);

-- Grupo 2 e 3: mesmos produtos em outros depositos, saldos variados
;WITH nums AS (
    SELECT 1 AS n
    UNION ALL
    SELECT n + 1 FROM nums WHERE n < 20
)
INSERT INTO estoque.estoque
(cd_produto, cd_deposito, qt_estoque, qt_minima)
SELECT
    n,
    (n % 20) + 1,
    (n * 13) % 80 + 3,
    CASE n % 3 WHEN 0 THEN 10 WHEN 1 THEN 20 ELSE 30 END
FROM nums
UNION ALL
SELECT
    n,
    ((n + 4) % 20) + 1,
    (n * 7) % 60 + 5,
    CASE n % 2 WHEN 0 THEN 15 ELSE 25 END
FROM nums;

-- =============================================
-- CLIENTE (20)
-- =============================================
INSERT INTO estoque.cliente
(nm_cliente, ds_email, nr_cpf)
VALUES
('Joao Silva','joao@email.com','12345678901'),
('Maria Souza','maria@email.com','12345678902'),
('Pedro Santos','pedro@email.com','12345678903'),
('Ana Costa','ana@email.com','12345678904'),
('Lucas Oliveira','lucas@email.com','12345678905'),
('Julia Lima','julia@email.com','12345678906'),
('Carlos Alves','carlos@email.com','12345678907'),
('Mariana Rocha','mariana@email.com','12345678908'),
('Rafael Gomes','rafael@email.com','12345678909'),
('Beatriz Martins','beatriz@email.com','12345678910'),
('Gabriel Ferreira','gabriel@email.com','12345678911'),
('Larissa Ribeiro','larissa@email.com','12345678912'),
('Felipe Carvalho','felipe@email.com','12345678913'),
('Camila Pereira','camila@email.com','12345678914'),
('Bruno Rodrigues','bruno@email.com','12345678915'),
('Amanda Nunes','amanda@email.com','12345678916'),
('Thiago Barbosa','thiago@email.com','12345678917'),
('Isabela Mendes','isabela@email.com','12345678918'),
('Vinicius Cardoso','vinicius@email.com','12345678919'),
('Fernanda Dias','fernanda@email.com','12345678920');

-- =============================================
-- PEDIDO (40) - status: 1=pendente 2=pago 3=enviado 4=cancelado
-- Clientes 1, 2 e 6 compram varias vezes
-- =============================================
INSERT INTO estoque.pedido
(cd_cliente, cd_deposito, tp_status)
VALUES
-- pedidos 1 a 20
(1,1,1),(2,2,2),(3,3,1),(4,4,3),
(5,5,1),(6,6,2),(7,7,1),(8,8,3),
(9,9,1),(10,10,2),(11,11,1),(12,12,3),
(13,13,1),(14,14,2),(15,15,1),(16,16,3),
(17,17,1),(18,18,2),(19,19,1),(20,20,3),
-- pedidos 21 a 40
(2,2,2),(2,3,2),(6,6,2),(1,1,2),
(1,4,2),(3,3,2),(5,5,3),(10,10,2),
(14,14,1),(7,7,2),(8,8,4),(9,9,2),
(11,11,2),(12,12,4),(2,2,2),(15,15,2),
(4,4,2),(1,1,3),(13,13,2),(6,6,2);

-- =============================================
-- ITEM_PEDIDO (varios itens por pedido; valor = preco do produto)
-- =============================================
INSERT INTO estoque.item_pedido
(cd_pedido, cd_produto, qt_item, vl_unitario)
VALUES
-- um item por pedido (pedidos 1 a 20)
(1,1,2,1500),(2,2,1,4500),
(3,3,1,3500),(4,4,2,2800),
(5,5,1,2200),(6,6,2,1200),
(7,7,3,150),(8,8,1,400),
(9,9,2,350),(10,10,1,180),
(11,11,2,130),(12,12,1,200),
(13,13,1,2800),(14,14,2,250),
(15,15,5,5),(16,16,10,3),
(17,17,1,120),(18,18,2,150),
(19,19,1,90),(20,20,1,600),
-- itens extras nos pedidos pagos iniciais
(2,7,2,150),(2,22,1,99),
(6,10,3,180),(6,23,1,150),
(10,8,1,400),(10,24,2,120),
(14,17,2,120),
(18,28,1,100),(18,21,1,299),
-- pedidos 21 a 40
(21,7,5,150),(21,8,2,400),(21,15,20,5),
(22,10,4,180),(22,11,3,130),(22,25,2,35),
(23,7,3,150),(23,16,30,3),
(24,7,10,150),(24,19,5,90),(24,33,1,400),
(25,15,50,5),(25,16,40,3),
(26,1,1,1500),(26,8,2,400),(26,21,1,299),
(27,9,3,350),
(28,2,1,4500),(28,20,1,600),
(29,12,2,200),
(30,7,4,150),(30,10,2,180),
(31,14,1,250),
(32,17,5,120),(32,18,5,150),
(33,11,6,130),(33,26,1,80),
(34,19,2,90),
(35,7,6,150),(35,40,1,350),
(36,3,1,3500),(36,32,1,250),
(37,5,1,2200),(37,24,1,120),
(38,13,1,2800),
(39,16,12,3),(39,15,10,5),(39,36,2,25),
(40,7,2,150),(40,9,1,350),(40,38,1,50);

-- Atualizar total dos pedidos
UPDATE estoque.pedido
SET vl_total = estoque.fn_total_pedido(cd_pedido);

-- =============================================
-- MOVIMENTACAO_ESTOQUE
-- O trigger tr_atualizar_estoque (criado no DDL) ajusta o saldo.
-- =============================================
INSERT INTO estoque.movimentacao_estoque
(cd_produto, cd_deposito, tp_movimentacao,
 qt_movimentada, dt_movimentacao)
VALUES
-- entradas
(1,1,'E',10,GETDATE()),
(2,2,'E',15,GETDATE()),
(3,3,'E',20,GETDATE()),
(4,4,'E',10,GETDATE()),
(5,5,'E',12,GETDATE()),
(6,6,'E',15,GETDATE()),
(7,7,'E',20,GETDATE()),
(8,8,'E',10,GETDATE()),
(9,9,'E',15,GETDATE()),
(10,10,'E',20,GETDATE()),
-- saidas
(11,11,'S',5,GETDATE()),
(12,12,'S',5,GETDATE()),
(13,13,'S',10,GETDATE()),
(14,14,'S',5,GETDATE()),
(15,15,'S',10,GETDATE()),
(16,16,'S',5,GETDATE()),
(17,17,'S',5,GETDATE()),
(18,18,'S',5,GETDATE()),
(19,19,'S',10,GETDATE()),
(20,20,'S',5,GETDATE()),
-- movimentacoes em outros depositos
(1,2,'E',10,GETDATE()),
(5,6,'E',20,GETDATE()),
(7,8,'S',5,GETDATE()),
(10,11,'S',10,GETDATE()),
(13,14,'S',8,GETDATE()),
(19,20,'S',4,GETDATE());

-- =============================================
-- CONTAGEM DE REGISTROS
-- =============================================
SELECT 'categoria' AS tabela, COUNT(*) AS linhas FROM estoque.categoria
UNION ALL
SELECT 'marca', COUNT(*) FROM estoque.marca
UNION ALL
SELECT 'produto', COUNT(*) FROM estoque.produto
UNION ALL
SELECT 'produto_fisico', COUNT(*) FROM estoque.produto_fisico
UNION ALL
SELECT 'produto_digital', COUNT(*) FROM estoque.produto_digital
UNION ALL
SELECT 'fornecedor', COUNT(*) FROM estoque.fornecedor
UNION ALL
SELECT 'produto_fornecedor', COUNT(*) FROM estoque.produto_fornecedor
UNION ALL
SELECT 'deposito', COUNT(*) FROM estoque.deposito
UNION ALL
SELECT 'estoque', COUNT(*) FROM estoque.estoque
UNION ALL
SELECT 'cliente', COUNT(*) FROM estoque.cliente
UNION ALL
SELECT 'pedido', COUNT(*) FROM estoque.pedido
UNION ALL
SELECT 'item_pedido', COUNT(*) FROM estoque.item_pedido
UNION ALL
SELECT 'movimentacao_estoque', COUNT(*) FROM estoque.movimentacao_estoque;
