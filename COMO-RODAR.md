# Como rodar o projeto localmente

Passo a passo para montar o **banco**, o **servidor** e a **tela de Fornecedores** na sua máquina (Windows).

Cada integrante tem a **sua própria cópia** do banco. Os scripts em `DB/` deixam todas as cópias iguais.

```
Navegador (FrontEnd/)  ──fetch──►  Node.js + Express (backend/)  ──mssql──►  SQL Server
   fornecedores.html                   server.js  /api/fornecedores            estoque.fornecedor
```

---

## Sumário

1. [Pré-requisitos](#1-pré-requisitos)
2. [Configurar o SQL Server](#2-configurar-o-sql-server)
3. [Criar o banco](#3-criar-o-banco)
4. [Configurar o backend](#4-configurar-o-backend)
5. [Rodar](#5-rodar)
6. [Rotas da API](#6-rotas-da-api)
7. [Problemas comuns](#7-problemas-comuns)

---

## 1. Pré-requisitos

| Programa | Para quê | Onde baixar |
|---|---|---|
| **SQL Server Express** (2016 ou mais novo) | o banco de dados | [microsoft.com/sql-server/sql-server-downloads](https://www.microsoft.com/pt-br/sql-server/sql-server-downloads) → *Express* → instalação **Básica** |
| **SSMS** | rodar os scripts SQL | [Instalar o SSMS](https://learn.microsoft.com/pt-br/ssms/install/install) (só os componentes principais) |
| **Node.js** (versão LTS) | rodar o servidor | [nodejs.org](https://nodejs.org) |
| **VSCode** + extensão **REST Client** (Huachao Mao) | editar e testar a API | opcional, mas recomendado |

Confira o Node no terminal:

```bash
node -v
```

---

## 2. Configurar o SQL Server

Faça **uma vez** por máquina.

### 2.1 Conectar no SSMS
- **Nome do Servidor:** `localhost\SQLEXPRESS`
- **Autenticação:** Autenticação do Windows
- Marque **Certificado do Servidor de Confiança**

### 2.2 Habilitar login com usuário e senha
O Node precisa de usuário e senha; a instalação Básica só aceita o login do Windows.

1. Botão direito em `localhost\SQLEXPRESS` → **Propriedades** → **Segurança**
2. Marque **Modo de Autenticação do SQL Server e do Windows** → **OK**
3. Botão direito em `localhost\SQLEXPRESS` → **Reiniciar**

### 2.3 Habilitar a porta TCP 1433
É por ela que o Node conversa com o banco.

1. Abra o **SQL Server Configuration Manager** (ou `Win + R` → `SQLServerManager17.msc`; o número muda conforme a versão: 16 = 2022, 17 = 2025)
2. **Configuração de Rede do SQL Server** → **Protocolos para SQLEXPRESS**
3. Botão direito em **TCP/IP** → **Habilitar**
4. Duplo clique em **TCP/IP** → aba **Endereços IP** → seção **IPAll** (no final):
   - **Portas TCP Dinâmicas:** deixe **vazio**
   - **Porta TCP:** `1433`
5. **Serviços do SQL Server** → botão direito em **SQL Server (SQLEXPRESS)** → **Reiniciar**

---

## 3. Criar o banco

Rode os scripts **no SSMS**, nesta ordem, conectado com o login do Windows.

### 3.1 Banco e login da aplicação
1. Copie `DB/00-setup.example.sql` para **`DB/00-setup.sql`** (este arquivo é ignorado pelo Git)
2. Na cópia, use **Ctrl + H** para trocar:
   - `NOME_DO_BANCO` → nome do banco (ex.: `EstoqueEcommerce`)
   - `NOME_DO_LOGIN` → usuário da aplicação (ex.: `app_estoque`)
   - `TROQUE_AQUI` → uma senha (8+ caracteres, com maiúscula, minúscula, número e símbolo)
3. Abra a cópia no SSMS e aperte **F5**

> O login criado só pode **ler e gravar dados** — não pode apagar tabelas. Anote os três valores: eles vão para o `.env`.

### 3.2 Tabelas e dados
1. No **Pesquisador de Objetos**, botão direito no seu banco → **Nova Consulta**
2. Confira se a caixa no topo mostra **o seu banco** (e não `master`)
3. Cole e rode (**F5**), nesta ordem:
   1. `DB/DDL.sql` — cria as tabelas
   2. `DB/DML.sql` — insere os dados

Teste:

```sql
SELECT * FROM estoque.fornecedor; -- deve trazer 20 linhas
```

---

## 4. Configurar o backend

No terminal, a partir da raiz do repositório:

```bash
cd backend
```
```bash
npm install
```

Copie `backend/.env.example` para **`backend/.env`** (ignorado pelo Git) e preencha:

```
DB_SERVER=localhost
DB_PORT=1433
DB_NAME=EstoqueEcommerce
DB_USER=app_estoque
DB_PASSWORD=sua_senha
PORT=3000
```

> Sem espaços em volta do `=` e sem aspas. Use os mesmos valores do seu `00-setup.sql`.

---

## 5. Rodar

Dentro de `backend/`:

```bash
node server.js
```

Deve aparecer `Servidor rodando em http://localhost:3000`. Para desligar: **Ctrl + C**.

| Endereço | O que abre |
|---|---|
| http://localhost:3000/ | Painel de vendas |
| http://localhost:3000/fornecedores.html | **CRUD de Fornecedores** |
| http://localhost:3000/api/fornecedores | dados em JSON (API) |

> Mudou o `server.js`? Reinicie o servidor. Mudou algo em `FrontEnd/`? Basta recarregar a página (F5).

---

## 6. Rotas da API

| Ação | Método | Rota | Respostas |
|---|---|---|---|
| Listar | `GET` | `/api/fornecedores?status=ativos\|inativos\|todos` | 200, 400 (status inválido) |
| Buscar um | `GET` | `/api/fornecedores/:id` | 200, 404 |
| Cadastrar | `POST` | `/api/fornecedores` | 201, 400, 409 (CNPJ repetido) |
| Atualizar | `PUT` | `/api/fornecedores/:id` | 200, 400, 404, 409 |
| Excluir | `DELETE` | `/api/fornecedores/:id` | 200 (`acao: excluido` ou `desativado`), 404 |

**Regras importantes**
- A listagem mostra **só ativos** por padrão.
- **Excluir** um fornecedor **sem** produtos apaga de verdade; **com** produtos vinculados (`produto_fornecedor`) ele é **desativado** (`is_ativo = 0`), preservando o histórico.
- Para **reativar**: editar e marcar *Fornecedor ativo* (ou `PUT` com `"is_ativo": true`).
- Todas as consultas usam **parâmetros** (proteção contra SQL Injection).

Para testar sem a tela: abra `backend/fornecedores.http` no VSCode e clique em **Send Request** acima de cada requisição.

---

## 7. Problemas comuns

| Sintoma | Causa provável | Solução |
|---|---|---|
| `npm.ps1 não pode ser carregado` | PowerShell bloqueia scripts | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` ou use o terminal **Command Prompt** |
| `node não é reconhecido` | Node recém-instalado | feche e abra o VSCode (ou reinicie o PC) |
| `Failed to connect to localhost:1433` | TCP/IP desligado ou porta errada | refaça o passo [2.3](#23-habilitar-a-porta-tcp-1433) |
| `Login failed for user` | modo misto desligado ou senha diferente | refaça o [2.2](#22-habilitar-login-com-usuário-e-senha); confira o `.env` |
| `Invalid object name 'estoque.fornecedor'` | DDL rodou no banco `master` | rode o `DDL.sql` e o `DML.sql` de novo com o seu banco selecionado |
| `self-signed certificate` | certificado do Express | o `db.js` já usa `trustServerCertificate: true`; confira se não foi removido |
| `Cannot GET /...` | rota ou arquivo não existe | confira o endereço; páginas ficam em `FrontEnd/` |
| `git add` → `pathspec did not match` | terminal dentro de `backend/` | volte à raiz (`cd ..`) antes dos comandos do Git |
