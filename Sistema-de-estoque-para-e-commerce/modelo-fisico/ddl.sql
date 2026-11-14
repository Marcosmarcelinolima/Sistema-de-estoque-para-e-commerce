/* =====================================================================
   BANCO DE DADOS II - SISTEMA DE ESTOQUE PARA E-COMMERCE
   01_ddl.sql : schema, tabelas, indices, function, trigger e procedure
   SGBD: PostgreSQL 12+ (testado no 16)
   Convencao: cd_ codigo | nm_ nome | ds_ descricao | dt_ data | tp_ tipo
              is_ flag   | qt_ quantidade | vl_ valor | nr_ numero | sg_ sigla
   ATENCAO: recria o schema "estoque" do zero (apaga o que existir nele).
   No DBeaver execute como SCRIPT: Alt + X.
   ===================================================================== */

DROP SCHEMA IF EXISTS estoque CASCADE;
CREATE SCHEMA estoque;
SET search_path TO estoque;

-- =====================================================================
-- TABELAS (13)
-- =====================================================================

CREATE TABLE categoria (
    cd_categoria  smallint GENERATED ALWAYS AS IDENTITY NOT NULL,
    nm_categoria  varchar(50) NOT NULL,
    CONSTRAINT pk_categoria PRIMARY KEY (cd_categoria),
    CONSTRAINT uq_categoria_nm UNIQUE (nm_categoria)
);

CREATE TABLE marca (
    cd_marca  smallint GENERATED ALWAYS AS IDENTITY NOT NULL,
    nm_marca  varchar(50) NOT NULL,
    CONSTRAINT pk_marca PRIMARY KEY (cd_marca),
    CONSTRAINT uq_marca_nm UNIQUE (nm_marca)
);

-- SUPERTIPO (generalizacao)
CREATE TABLE produto (
    cd_produto    integer GENERATED ALWAYS AS IDENTITY NOT NULL,
    cd_categoria  smallint      NOT NULL,
    cd_marca      smallint      NOT NULL,
    nm_produto    varchar(100)  NOT NULL,
    vl_preco      numeric(10,2) NOT NULL,
    tp_produto    char(1)       NOT NULL,                  -- F = fisico, D = digital (discriminador)
    is_ativo      boolean       NOT NULL CONSTRAINT df_produto_is_ativo DEFAULT true,
    dt_cadastro   date          NOT NULL CONSTRAINT df_produto_dt_cadastro DEFAULT CURRENT_DATE,
    CONSTRAINT pk_produto PRIMARY KEY (cd_produto),
    CONSTRAINT fk_categoria__produto FOREIGN KEY (cd_categoria) REFERENCES categoria (cd_categoria),
    CONSTRAINT fk_marca__produto FOREIGN KEY (cd_marca) REFERENCES marca (cd_marca),
    CONSTRAINT ck_produto_vl_preco CHECK (vl_preco > 0),
    CONSTRAINT ck_produto_tp_produto CHECK (tp_produto IN ('F', 'D'))
);

-- SUBTIPO 1 (especializacao): PK = FK para o supertipo
CREATE TABLE produto_fisico (
    cd_produto         integer      NOT NULL,
    vl_peso_kg         numeric(6,3) NOT NULL,
    vl_altura_cm       numeric(5,1) NOT NULL,
    vl_largura_cm      numeric(5,1) NOT NULL,
    vl_comprimento_cm  numeric(5,1) NOT NULL,
    is_fragil          boolean      NOT NULL CONSTRAINT df_produto_fisico_is_fragil DEFAULT false,
    CONSTRAINT pk_produto_fisico PRIMARY KEY (cd_produto),
    CONSTRAINT fk_produto__produto_fisico FOREIGN KEY (cd_produto) REFERENCES produto (cd_produto),
    CONSTRAINT ck_produto_fisico_peso CHECK (vl_peso_kg > 0),
    CONSTRAINT ck_produto_fisico_medidas CHECK (vl_altura_cm > 0 AND vl_largura_cm > 0 AND vl_comprimento_cm > 0)
);

-- SUBTIPO 2 (especializacao)
CREATE TABLE produto_digital (
    cd_produto         integer      NOT NULL,
    ds_url_download    varchar(200) NOT NULL,
    vl_tamanho_mb      numeric(8,2) NOT NULL,
    qt_max_downloads   smallint     NOT NULL CONSTRAINT df_produto_digital_qt_max DEFAULT 3,
    CONSTRAINT pk_produto_digital PRIMARY KEY (cd_produto),
    CONSTRAINT fk_produto__produto_digital FOREIGN KEY (cd_produto) REFERENCES produto (cd_produto),
    CONSTRAINT ck_produto_digital_tamanho CHECK (vl_tamanho_mb > 0),
    CONSTRAINT ck_produto_digital_downloads CHECK (qt_max_downloads > 0)
);

CREATE TABLE fornecedor (
    cd_fornecedor  smallint GENERATED ALWAYS AS IDENTITY NOT NULL,
    nm_fornecedor  varchar(100) NOT NULL,
    nr_cnpj        char(14)     NOT NULL,
    ds_email       varchar(100) NOT NULL,
    nr_telefone    varchar(11)  NULL,
    is_ativo       boolean      NOT NULL CONSTRAINT df_fornecedor_is_ativo DEFAULT true,
    CONSTRAINT pk_fornecedor PRIMARY KEY (cd_fornecedor),
    CONSTRAINT uq_fornecedor_cnpj UNIQUE (nr_cnpj),
    CONSTRAINT ck_fornecedor_cnpj CHECK (nr_cnpj ~ '^[0-9]{14}$'),
    CONSTRAINT ck_fornecedor_email CHECK (ds_email ~ '^[^@]+@[^@]+\.[^@]+$')
);

-- N:N produto x fornecedor
CREATE TABLE produto_fornecedor (
    cd_produto      integer       NOT NULL,
    cd_fornecedor   smallint      NOT NULL,
    vl_custo        numeric(10,2) NOT NULL,
    qt_prazo_dias   smallint      NOT NULL CONSTRAINT df_produto_fornecedor_prazo DEFAULT 7,
    CONSTRAINT pk_produto_fornecedor PRIMARY KEY (cd_produto, cd_fornecedor),
    CONSTRAINT fk_produto__produto_fornecedor FOREIGN KEY (cd_produto) REFERENCES produto (cd_produto),
    CONSTRAINT fk_fornecedor__produto_fornecedor FOREIGN KEY (cd_fornecedor) REFERENCES fornecedor (cd_fornecedor),
    CONSTRAINT ck_produto_fornecedor_custo CHECK (vl_custo >= 0),
    CONSTRAINT ck_produto_fornecedor_prazo CHECK (qt_prazo_dias BETWEEN 0 AND 255)
);

CREATE TABLE deposito (
    cd_deposito  smallint GENERATED ALWAYS AS IDENTITY NOT NULL,
    nm_deposito  varchar(60) NOT NULL,
    nm_cidade    varchar(60) NOT NULL,
    sg_uf        char(2)     NOT NULL,
    CONSTRAINT pk_deposito PRIMARY KEY (cd_deposito),
    CONSTRAINT uq_deposito_nm UNIQUE (nm_deposito)
);

-- N:N produto x deposito (so produto FISICO tem estoque: FK aponta para produto_fisico)
CREATE TABLE estoque (
    cd_produto   integer  NOT NULL,
    cd_deposito  smallint NOT NULL,
    qt_estoque   integer  NOT NULL CONSTRAINT df_estoque_qt_estoque DEFAULT 0,
    qt_minima    smallint NOT NULL CONSTRAINT df_estoque_qt_minima DEFAULT 10,
    CONSTRAINT pk_estoque PRIMARY KEY (cd_produto, cd_deposito),
    CONSTRAINT fk_produto_fisico__estoque FOREIGN KEY (cd_produto) REFERENCES produto_fisico (cd_produto),
    CONSTRAINT fk_deposito__estoque FOREIGN KEY (cd_deposito) REFERENCES deposito (cd_deposito),
    CONSTRAINT ck_estoque_qt_estoque CHECK (qt_estoque >= 0),
    CONSTRAINT ck_estoque_qt_minima CHECK (qt_minima >= 0)
);

CREATE TABLE cliente (
    cd_cliente   integer GENERATED ALWAYS AS IDENTITY NOT NULL,
    nm_cliente   varchar(100) NOT NULL,
    ds_email     varchar(100) NOT NULL,
    nr_cpf       char(11)     NOT NULL,
    dt_cadastro  date         NOT NULL CONSTRAINT df_cliente_dt_cadastro DEFAULT CURRENT_DATE,
    CONSTRAINT pk_cliente PRIMARY KEY (cd_cliente),
    CONSTRAINT uq_cliente_email UNIQUE (ds_email),
    CONSTRAINT uq_cliente_cpf UNIQUE (nr_cpf),
    CONSTRAINT ck_cliente_cpf CHECK (nr_cpf ~ '^[0-9]{11}$'),
    CONSTRAINT ck_cliente_email CHECK (ds_email ~ '^[^@]+@[^@]+\.[^@]+$')
);

CREATE TABLE pedido (
    cd_pedido    integer GENERATED ALWAYS AS IDENTITY NOT NULL,
    cd_cliente   integer       NOT NULL,
    cd_deposito  smallint      NOT NULL,
    tp_status    smallint      NOT NULL CONSTRAINT df_pedido_tp_status DEFAULT 1,     -- 1=pendente 2=pago 3=enviado 4=cancelado
    dt_pedido    timestamp(0)  NOT NULL CONSTRAINT df_pedido_dt_pedido DEFAULT LOCALTIMESTAMP(0),
    vl_total     numeric(12,2) NOT NULL CONSTRAINT df_pedido_vl_total DEFAULT 0,      -- desnormalizado (ver README)
    CONSTRAINT pk_pedido PRIMARY KEY (cd_pedido),
    CONSTRAINT fk_cliente__pedido FOREIGN KEY (cd_cliente) REFERENCES cliente (cd_cliente),
    CONSTRAINT fk_deposito__pedido FOREIGN KEY (cd_deposito) REFERENCES deposito (cd_deposito),
    CONSTRAINT ck_pedido_tp_status CHECK (tp_status IN (1, 2, 3, 4)),
    CONSTRAINT ck_pedido_vl_total CHECK (vl_total >= 0)
);

-- N:N pedido x produto
CREATE TABLE item_pedido (
    cd_pedido    integer       NOT NULL,
    cd_produto   integer       NOT NULL,
    qt_item      smallint      NOT NULL,
    vl_unitario  numeric(10,2) NOT NULL,                  -- preco no momento da venda (historico)
    CONSTRAINT pk_item_pedido PRIMARY KEY (cd_pedido, cd_produto),
    CONSTRAINT fk_pedido__item_pedido FOREIGN KEY (cd_pedido) REFERENCES pedido (cd_pedido),
    CONSTRAINT fk_produto__item_pedido FOREIGN KEY (cd_produto) REFERENCES produto (cd_produto),
    CONSTRAINT ck_item_pedido_qt_item CHECK (qt_item > 0),
    CONSTRAINT ck_item_pedido_vl_unitario CHECK (vl_unitario >= 0)
);

-- Historico de entradas (E) e saidas (S) de estoque
CREATE TABLE movimentacao_estoque (
    cd_movimentacao  integer GENERATED ALWAYS AS IDENTITY NOT NULL,
    cd_produto       integer      NOT NULL,
    cd_deposito      smallint     NOT NULL,
    tp_movimentacao  char(1)      NOT NULL,               -- E = entrada, S = saida
    qt_movimentada   integer      NOT NULL,               -- sempre positivo; o tipo define o sinal
    dt_movimentacao  timestamp(0) NOT NULL CONSTRAINT df_movimentacao_dt DEFAULT LOCALTIMESTAMP(0),
    CONSTRAINT pk_movimentacao_estoque PRIMARY KEY (cd_movimentacao),
    CONSTRAINT fk_estoque__movimentacao_estoque FOREIGN KEY (cd_produto, cd_deposito) REFERENCES estoque (cd_produto, cd_deposito),
    CONSTRAINT ck_movimentacao_tp CHECK (tp_movimentacao IN ('E', 'S')),
    CONSTRAINT ck_movimentacao_qt CHECK (qt_movimentada > 0)
);

-- =====================================================================
-- INDICES (um por consulta de negocio - ver 03_consultas.sql)
-- =====================================================================

-- Q1: produtos de uma categoria
CREATE INDEX ix_produto_cd_categoria ON produto (cd_categoria) INCLUDE (nm_produto, vl_preco);
-- Q2: produtos com estoque baixo
CREATE INDEX ix_estoque_qt_estoque ON estoque (qt_estoque) INCLUDE (qt_minima);
-- Q3: total gasto por cliente
CREATE INDEX ix_pedido_cd_cliente ON pedido (cd_cliente) INCLUDE (vl_total);
-- Q4: produtos mais vendidos
CREATE INDEX ix_item_pedido_cd_produto ON item_pedido (cd_produto) INCLUDE (qt_item);
-- Q5: pedidos por periodo e status
CREATE INDEX ix_pedido_dt_pedido ON pedido (dt_pedido) INCLUDE (tp_status, vl_total);
-- Q6: produtos fornecidos por um fornecedor
CREATE INDEX ix_produto_fornecedor_cd_fornecedor ON produto_fornecedor (cd_fornecedor) INCLUDE (vl_custo, qt_prazo_dias);
-- Q7: historico de movimentacao de um produto
CREATE INDEX ix_movimentacao_produto_dt ON movimentacao_estoque (cd_produto, dt_movimentacao);

-- =====================================================================
-- FUNCTION: total de um pedido (soma dos itens)
-- =====================================================================
CREATE FUNCTION fn_total_pedido(p_cd_pedido integer)
RETURNS numeric(12,2)
LANGUAGE sql
STABLE
SET search_path = estoque
AS $$
    SELECT COALESCE(SUM(qt_item * vl_unitario), 0)::numeric(12,2)
    FROM item_pedido
    WHERE cd_pedido = p_cd_pedido;
$$;

-- =====================================================================
-- TRIGGER: toda movimentacao atualiza o saldo da tabela estoque
-- (se a saida deixar o saldo negativo, o CHECK de estoque cancela tudo)
-- =====================================================================
CREATE FUNCTION fn_movimentacao_atualiza_estoque()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = estoque
AS $$
BEGIN
    UPDATE estoque e
    SET qt_estoque = e.qt_estoque + m.saldo
    FROM (SELECT cd_produto,
                 cd_deposito,
                 SUM(CASE tp_movimentacao WHEN 'E' THEN qt_movimentada ELSE -qt_movimentada END) AS saldo
          FROM novas
          GROUP BY cd_produto, cd_deposito) m
    WHERE m.cd_produto = e.cd_produto
      AND m.cd_deposito = e.cd_deposito;

    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_movimentacao_atualiza_estoque
AFTER INSERT ON movimentacao_estoque
REFERENCING NEW TABLE AS novas
FOR EACH STATEMENT
EXECUTE FUNCTION fn_movimentacao_atualiza_estoque();

-- =====================================================================
-- STORED PROCEDURE: registra a venda de um produto fisico em um pedido
--   1) grava o item  2) da baixa no estoque (via trigger)  3) recalcula o total
-- Se algo falhar (produto inexistente, estoque insuficiente), tudo e desfeito.
-- =====================================================================
CREATE PROCEDURE sp_registrar_venda(
    p_cd_pedido   integer,
    p_cd_produto  integer,
    p_cd_deposito integer,
    p_qt_item     integer
)
LANGUAGE plpgsql
SET search_path = estoque
AS $$
DECLARE
    v_preco numeric(10,2);
BEGIN
    SELECT vl_preco INTO v_preco FROM produto WHERE cd_produto = p_cd_produto;
    IF v_preco IS NULL THEN
        RAISE EXCEPTION 'Produto inexistente.';
    END IF;

    INSERT INTO item_pedido (cd_pedido, cd_produto, qt_item, vl_unitario)
    VALUES (p_cd_pedido, p_cd_produto, p_qt_item, v_preco);

    -- o trigger desconta do estoque; sem saldo suficiente o CHECK falha e tudo e desfeito
    INSERT INTO movimentacao_estoque (cd_produto, cd_deposito, tp_movimentacao, qt_movimentada)
    VALUES (p_cd_produto, p_cd_deposito, 'S', p_qt_item);

    UPDATE pedido
    SET vl_total = fn_total_pedido(p_cd_pedido)
    WHERE cd_pedido = p_cd_pedido;
END;
$$;
