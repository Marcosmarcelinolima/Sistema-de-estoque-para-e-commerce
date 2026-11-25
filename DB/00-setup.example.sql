-- 1. Cria o banco
IF DB_ID('NOME_DO_BANCO') IS NULL
    CREATE DATABASE NOME_DO_BANCO;
GO

-- 2. Cria o LOGIN (a "chave" para entrar no SERVIDOR)
IF SUSER_ID('NOME_DO_LOGIN') IS NULL
    CREATE LOGIN NOME_DO_LOGIN
    WITH PASSWORD = 'TROQUE_AQUI',
         DEFAULT_DATABASE = NOME_DO_BANCO;
GO

-- 3. Entra no banco novo
USE NOME_DO_BANCO;
GO

-- 4. Cria o USUÁRIO (a "permissão" dentro DESTE banco), ligado ao login
IF USER_ID('NOME_DO_LOGIN') IS NULL
    CREATE USER NOME_DO_LOGIN FOR LOGIN NOME_DO_LOGIN;
GO

-- 5. Dá só as permissões que a aplicação precisa
ALTER ROLE db_datareader ADD MEMBER NOME_DO_LOGIN; -- SELECT
ALTER ROLE db_datawriter ADD MEMBER NOME_DO_LOGIN; -- INSERT, UPDATE, DELETE
GRANT EXECUTE TO NOME_DO_LOGIN;                    -- functions e procedures
GO

-- 6. Arquivo molde example