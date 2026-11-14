/* =====================================================================
   BANCO DE DADOS II - SISTEMA DE ESTOQUE PARA E-COMMERCE
   DDL.sql : schema, tabelas, function de total e triggers
   SGBD: SQL Server 2016+ (SSMS)

   ORDEM DE EXECUCAO:  1) DDL.sql   2) DML.sql   3) Consultas.sql

   Convencao: cd_ codigo | nm_ nome | ds_ descricao | dt_ data | tp_ tipo
              is_ flag   | qt_ quantidade | vl_ valor | nr_ numero | sg_ sigla
   ATENCAO: recria as tabelas do schema "estoque" do zero (apaga os dados).
   ===================================================================== */

-- 0. Garante que o schema existe
IF SCHEMA_ID('estoque') IS NULL
    EXEC('CREATE SCHEMA estoque');
GO

-- 1. Limpeza de objetos existentes (ordem inversa de dependencia)
DROP PROCEDURE IF EXISTS estoque.sp_registrar_reposicao;
DROP FUNCTION  IF EXISTS estoque.fn_margem_lucro;
DROP FUNCTION  IF EXISTS estoque.fn_total_pedido;

DROP TABLE IF EXISTS estoque.movimentacao_estoque;
DROP TABLE IF EXISTS estoque.item_pedido;
DROP TABLE IF EXISTS estoque.pedido;
DROP TABLE IF EXISTS estoque.cliente;
DROP TABLE IF EXISTS estoque.estoque;
DROP TABLE IF EXISTS estoque.deposito;
DROP TABLE IF EXISTS estoque.produto_fornecedor;
DROP TABLE IF EXISTS estoque.fornecedor;
DROP TABLE IF EXISTS estoque.produto_digital;
DROP TABLE IF EXISTS estoque.produto_fisico;
DROP TABLE IF EXISTS estoque.produto;
DROP TABLE IF EXISTS estoque.marca;
DROP TABLE IF EXISTS estoque.categoria;
GO

-- =====================================================================
-- TABELAS (13)
-- =====================================================================

CREATE TABLE estoque.categoria (
    cd_categoria SMALLINT IDENTITY(1,1) NOT NULL,
    nm_categoria VARCHAR(50) NOT NULL,
    CONSTRAINT pk_categoria PRIMARY KEY (cd_categoria),
    CONSTRAINT uq_categoria_nm UNIQUE (nm_categoria)
);

CREATE TABLE estoque.marca (
    cd_marca SMALLINT IDENTITY(1,1) NOT NULL,
    nm_marca VARCHAR(50) NOT NULL,
    CONSTRAINT pk_marca PRIMARY KEY (cd_marca),
    CONSTRAINT uq_marca_nm UNIQUE (nm_marca)
);

-- SUPERTIPO (generalizacao)
CREATE TABLE estoque.produto (
    cd_produto   INT IDENTITY(1,1) NOT NULL,
    cd_categoria SMALLINT          NOT NULL,
    cd_marca     SMALLINT          NOT NULL,
    nm_produto   VARCHAR(100)      NOT NULL,
    vl_preco     NUMERIC(10,2)     NOT NULL,
    tp_produto   CHAR(1)           NOT NULL, -- F = fisico, D = digital (discriminador)
    is_ativo     BIT               NOT NULL CONSTRAINT df_produto_is_ativo DEFAULT 1,
    dt_cadastro  DATE              NOT NULL CONSTRAINT df_produto_dt_cadastro DEFAULT CAST(GETDATE() AS DATE),
    CONSTRAINT pk_produto PRIMARY KEY (cd_produto),
    CONSTRAINT fk_categoria__produto FOREIGN KEY (cd_categoria) REFERENCES estoque.categoria (cd_categoria),
    CONSTRAINT fk_marca__produto FOREIGN KEY (cd_marca) REFERENCES estoque.marca (cd_marca),
    CONSTRAINT ck_produto_vl_preco CHECK (vl_preco > 0),
    CONSTRAINT ck_produto_tp_produto CHECK (tp_produto IN ('F', 'D'))
);

-- SUBTIPO 1 (especializacao): PK = FK para o supertipo
CREATE TABLE estoque.produto_fisico (
    cd_produto        INT          NOT NULL,
    vl_peso_kg        NUMERIC(6,3) NOT NULL,
    vl_altura_cm      NUMERIC(5,1) NOT NULL,
    vl_largura_cm     NUMERIC(5,1) NOT NULL,
    vl_comprimento_cm NUMERIC(5,1) NOT NULL,
    is_fragil         BIT          NOT NULL CONSTRAINT df_produto_fisico_is_fragil DEFAULT 0,
    CONSTRAINT pk_produto_fisico PRIMARY KEY (cd_produto),
    CONSTRAINT fk_produto__produto_fisico FOREIGN KEY (cd_produto) REFERENCES estoque.produto (cd_produto),
    CONSTRAINT ck_produto_fisico_peso CHECK (vl_peso_kg > 0),
    CONSTRAINT ck_produto_fisico_medidas CHECK (vl_altura_cm > 0 AND vl_largura_cm > 0 AND vl_comprimento_cm > 0)
);

-- SUBTIPO 2 (especializacao)
CREATE TABLE estoque.produto_digital (
    cd_produto       INT          NOT NULL,
    ds_url_download  VARCHAR(200) NOT NULL,
    vl_tamanho_mb    NUMERIC(8,2) NOT NULL,
    qt_max_downloads SMALLINT     NOT NULL CONSTRAINT df_produto_digital_qt_max DEFAULT 3,
    CONSTRAINT pk_produto_digital PRIMARY KEY (cd_produto),
    CONSTRAINT fk_produto__produto_digital FOREIGN KEY (cd_produto) REFERENCES estoque.produto (cd_produto),
    CONSTRAINT ck_produto_digital_tamanho CHECK (vl_tamanho_mb > 0),
    CONSTRAINT ck_produto_digital_downloads CHECK (qt_max_downloads > 0)
);

CREATE TABLE estoque.fornecedor (
    cd_fornecedor SMALLINT IDENTITY(1,1) NOT NULL,
    nm_fornecedor VARCHAR(100) NOT NULL,
    nr_cnpj       CHAR(14)     NOT NULL,
    ds_email      VARCHAR(100) NOT NULL,
    nr_telefone   VARCHAR(11)  NULL,
    is_ativo      BIT          NOT NULL CONSTRAINT df_fornecedor_is_ativo DEFAULT 1,
    CONSTRAINT pk_fornecedor PRIMARY KEY (cd_fornecedor),
    CONSTRAINT uq_fornecedor_cnpj UNIQUE (nr_cnpj),
    CONSTRAINT ck_fornecedor_cnpj CHECK (LEN(nr_cnpj) = 14 AND nr_cnpj NOT LIKE '%[^0-9]%'),
    CONSTRAINT ck_fornecedor_email CHECK (ds_email LIKE '_%@_%._%')
);

-- N:N produto x fornecedor
CREATE TABLE estoque.produto_fornecedor (
    cd_produto    INT           NOT NULL,
    cd_fornecedor SMALLINT      NOT NULL,
    vl_custo      NUMERIC(10,2) NOT NULL,
    qt_prazo_dias SMALLINT      NOT NULL CONSTRAINT df_produto_fornecedor_prazo DEFAULT 7,
    CONSTRAINT pk_produto_fornecedor PRIMARY KEY (cd_produto, cd_fornecedor),
    CONSTRAINT fk_produto__produto_fornecedor FOREIGN KEY (cd_produto) REFERENCES estoque.produto (cd_produto),
    CONSTRAINT fk_fornecedor__produto_fornecedor FOREIGN KEY (cd_fornecedor) REFERENCES estoque.fornecedor (cd_fornecedor),
    CONSTRAINT ck_produto_fornecedor_custo CHECK (vl_custo >= 0),
    CONSTRAINT ck_produto_fornecedor_prazo CHECK (qt_prazo_dias BETWEEN 0 AND 255)
);

CREATE TABLE estoque.deposito (
    cd_deposito SMALLINT IDENTITY(1,1) NOT NULL,
    nm_deposito VARCHAR(60) NOT NULL,
    nm_cidade   VARCHAR(60) NOT NULL,
    sg_uf       CHAR(2)     NOT NULL,
    CONSTRAINT pk_deposito PRIMARY KEY (cd_deposito),
    CONSTRAINT uq_deposito_nm UNIQUE (nm_deposito)
);

-- N:N produto x deposito (so produto FISICO tem estoque: FK aponta para produto_fisico)
CREATE TABLE estoque.estoque (
    cd_produto  INT      NOT NULL,
    cd_deposito SMALLINT NOT NULL,
    qt_estoque  INT      NOT NULL CONSTRAINT df_estoque_qt_estoque DEFAULT 0,
    qt_minima   SMALLINT NOT NULL CONSTRAINT df_estoque_qt_minima DEFAULT 10,
    CONSTRAINT pk_estoque PRIMARY KEY (cd_produto, cd_deposito),
    CONSTRAINT fk_produto_fisico__estoque FOREIGN KEY (cd_produto) REFERENCES estoque.produto_fisico (cd_produto),
    CONSTRAINT fk_deposito__estoque FOREIGN KEY (cd_deposito) REFERENCES estoque.deposito (cd_deposito),
    CONSTRAINT ck_estoque_qt_estoque CHECK (qt_estoque >= 0),
    CONSTRAINT ck_estoque_qt_minima CHECK (qt_minima >= 0)
);

CREATE TABLE estoque.cliente (
    cd_cliente  INT IDENTITY(1,1) NOT NULL,
    nm_cliente  VARCHAR(100) NOT NULL,
    ds_email    VARCHAR(100) NOT NULL,
    nr_cpf      CHAR(11)     NOT NULL,
    dt_cadastro DATE         NOT NULL CONSTRAINT df_cliente_dt_cadastro DEFAULT CAST(GETDATE() AS DATE),
    CONSTRAINT pk_cliente PRIMARY KEY (cd_cliente),
    CONSTRAINT uq_cliente_email UNIQUE (ds_email),
    CONSTRAINT uq_cliente_cpf UNIQUE (nr_cpf),
    CONSTRAINT ck_cliente_cpf CHECK (LEN(nr_cpf) = 11 AND nr_cpf NOT LIKE '%[^0-9]%'),
    CONSTRAINT ck_cliente_email CHECK (ds_email LIKE '_%@_%._%')
);

CREATE TABLE estoque.pedido (
    cd_pedido   INT IDENTITY(1,1) NOT NULL,
    cd_cliente  INT           NOT NULL,
    cd_deposito SMALLINT      NOT NULL,
    tp_status   SMALLINT      NOT NULL CONSTRAINT df_pedido_tp_status DEFAULT 1, -- 1=pendente 2=pago 3=enviado 4=cancelado
    dt_pedido   DATETIME2(0)  NOT NULL CONSTRAINT df_pedido_dt_pedido DEFAULT SYSDATETIME(),
    vl_total    NUMERIC(12,2) NOT NULL CONSTRAINT df_pedido_vl_total DEFAULT 0,
    CONSTRAINT pk_pedido PRIMARY KEY (cd_pedido),
    CONSTRAINT fk_cliente__pedido FOREIGN KEY (cd_cliente) REFERENCES estoque.cliente (cd_cliente),
    CONSTRAINT fk_deposito__pedido FOREIGN KEY (cd_deposito) REFERENCES estoque.deposito (cd_deposito),
    CONSTRAINT ck_pedido_tp_status CHECK (tp_status IN (1, 2, 3, 4)),
    CONSTRAINT ck_pedido_vl_total CHECK (vl_total >= 0)
);

-- N:N pedido x produto
CREATE TABLE estoque.item_pedido (
    cd_pedido   INT           NOT NULL,
    cd_produto  INT           NOT NULL,
    qt_item     SMALLINT      NOT NULL,
    vl_unitario NUMERIC(10,2) NOT NULL, -- preco no momento da venda (historico)
    CONSTRAINT pk_item_pedido PRIMARY KEY (cd_pedido, cd_produto),
    CONSTRAINT fk_pedido__item_pedido FOREIGN KEY (cd_pedido) REFERENCES estoque.pedido (cd_pedido),
    CONSTRAINT fk_produto__item_pedido FOREIGN KEY (cd_produto) REFERENCES estoque.produto (cd_produto),
    CONSTRAINT ck_item_pedido_qt_item CHECK (qt_item > 0),
    CONSTRAINT ck_item_pedido_vl_unitario CHECK (vl_unitario >= 0)
);

-- Historico de entradas (E) e saidas (S) de estoque
CREATE TABLE estoque.movimentacao_estoque (
    cd_movimentacao INT IDENTITY(1,1) NOT NULL,
    cd_produto      INT          NOT NULL,
    cd_deposito     SMALLINT     NOT NULL,
    tp_movimentacao CHAR(1)      NOT NULL, -- E = entrada, S = saida
    qt_movimentada  INT          NOT NULL, -- sempre positivo; o tipo define o sinal
    dt_movimentacao DATETIME2(0) NOT NULL CONSTRAINT df_movimentacao_dt DEFAULT SYSDATETIME(),
    CONSTRAINT pk_movimentacao_estoque PRIMARY KEY (cd_movimentacao),
    CONSTRAINT fk_estoque__movimentacao_estoque FOREIGN KEY (cd_produto, cd_deposito) REFERENCES estoque.estoque (cd_produto, cd_deposito),
    CONSTRAINT ck_movimentacao_tp CHECK (tp_movimentacao IN ('E', 'S')),
    CONSTRAINT ck_movimentacao_qt CHECK (qt_movimentada > 0)
);
GO

-- =====================================================================
-- FUNCTION usada pelo DML para calcular o total dos pedidos
-- =====================================================================
CREATE OR ALTER FUNCTION estoque.fn_total_pedido
(
    @cd_pedido INT
)
RETURNS NUMERIC(12,2)
AS
BEGIN

    DECLARE @vl_total NUMERIC(12,2);

    SELECT @vl_total = SUM(qt_item * vl_unitario)
    FROM estoque.item_pedido
    WHERE cd_pedido = @cd_pedido;

    RETURN ISNULL(@vl_total, 0);

END;
GO

-- =====================================================================
-- TRIGGERS (regras de negocio das consultas 6 e 7)
-- Ficam no DDL para ja valerem durante a carga do DML.
-- =====================================================================

-- Consulta 7: atualiza o saldo do estoque a cada movimentacao
CREATE OR ALTER TRIGGER estoque.tr_atualizar_estoque
ON estoque.movimentacao_estoque
AFTER INSERT
AS
BEGIN

    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM estoque.estoque e
        INNER JOIN
        (
            SELECT
                cd_produto,
                cd_deposito,
                SUM(
                    CASE
                        WHEN tp_movimentacao = 'E'
                            THEN qt_movimentada
                        ELSE -qt_movimentada
                    END
                ) AS qt_alteracao
            FROM inserted
            GROUP BY cd_produto, cd_deposito
        ) m
            ON e.cd_produto = m.cd_produto
           AND e.cd_deposito = m.cd_deposito
        WHERE e.qt_estoque + m.qt_alteracao < 0
    )
    BEGIN

        ROLLBACK TRANSACTION;

        THROW 50003,
        'Estoque insuficiente para realizar a movimentacao.',
        1;

    END;

    UPDATE e
    SET e.qt_estoque = e.qt_estoque + m.qt_alteracao
    FROM estoque.estoque e
    INNER JOIN
    (
        SELECT
            cd_produto,
            cd_deposito,
            SUM(
                CASE
                    WHEN tp_movimentacao = 'E'
                        THEN qt_movimentada
                    ELSE -qt_movimentada
                END
            ) AS qt_alteracao
        FROM inserted
        GROUP BY cd_produto, cd_deposito
    ) m
        ON e.cd_produto = m.cd_produto
       AND e.cd_deposito = m.cd_deposito;

END;
GO

-- Consulta 6: impede venda de produto inativo
CREATE OR ALTER TRIGGER estoque.tr_bloquear_produto_inativo
ON estoque.item_pedido
AFTER INSERT
AS
BEGIN

    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        INNER JOIN estoque.produto p
            ON i.cd_produto = p.cd_produto
        WHERE p.is_ativo = 0
    )
    BEGIN

        ROLLBACK TRANSACTION;

        THROW 50004,
        'Operacao bloqueada: produto inativo nao pode ser vendido.',
        1;

    END;

END;
GO
