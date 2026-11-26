const express = require('express'); // carrega a biblioteca Express
const app = express();              // cria o servidor
app.use(express.json()); // habilita o servidor para receber JSON no corpo da requisição

// ROTA: quando alguém acessar GET /rota, responda com este JSON
app.get('/rota', (req, res) => {
  res.json({ mensagem: 'Olá! O servidor está funcionando.' });
});

// Liga o servidor na porta 3000 e fica esperando requisições
app.listen(3000, () => {
  console.log('Servidor rodando em http://localhost:3000');
});

const {pool, sql} = require('./db'); // importa o pool de conexões do banco de dados

app.get('/testedb', async (req, res) => { //req contem as infos do usuário, e res monta o corpo da resposta e envia ao servidor
    try {
        const conexao = await pool; // aguarda a conexão com o banco de dados
        const resultado = await conexao.request()
            .query('SELECT COUNT (*) AS total FROM estoque.Fornecedor'); // executa a consulta SQL
            res.json(resultado.recordset[0]); // envia o resultado da consulta como JSON
    } catch (erro) {
        res.status(500).json({ erro: erro.message }); // envia o erro como JSON para visualizar
    }
});


//ROTA DE LEITURA DE TODOS OS FORNECEDORES
app.get ('/api/fornecedores', async (req, res) => {
    try {
        const conexao = await pool;
        const resultado = await conexao.request()
            .query('SELECT cd_fornecedor, nm_fornecedor, nr_telefone FROM estoque.Fornecedor ORDER BY cd_fornecedor'); // executa a consulta SQL
            res.json(resultado.recordset); //envia o resultado da consulta como JSON
    } catch (erro) {
        res.status(500).json({ erro: erro.message }); // envia o erro como JSON para visualizar
    }
});


//ROTA DE LEITURA DE FORNECEDORES POR ID - LETRA R DO CRUD
app.get('/api/fornecedores/:id', async (req, res) => {
    try {
        const conexao = await pool;
        const resultado = await conexao.request()
            .input('id', sql.Int, req.params.id) 
            // adiciona o parâmetro de entrada para a consulta, ou seja, quando a rota recebe /api/fornecedores/1, o valor 1 será passado como parâmetro para a consulta SQL retornar o id 1


            .query('SELECT cd_fornecedor, nm_fornecedor, nr_telefone FROM estoque.Fornecedor WHERE cd_fornecedor = @id'); // executa a consulta SQL

            if (resultado.recordset.length === 0) {
                return res.status(404).json({ erro: 'Fornecedor não encontrado' }); 
                // envia erro 404 se não encontrar o fornecedor (se o fornecedor não existir)
            }

            res.json(resultado.recordset[0]); // envia o resultado da consulta como JSON   


        } catch (erro) {
            res.status(500).json({ erro: erro.message }); // envia o erro como JSON para visualizar
        }
    }
);


//ROTA DE CADASTRO DE FORNECEDORES - LETRA C DO CRUD
app.post('/api/fornecedores', async (req, res) => {
  // Pega os campos do corpo da requisição
  const { nm_fornecedor, nr_cnpj, ds_email, nr_telefone, is_ativo } = req.body;

  // Validação mínima: campos obrigatórios
  if (!nm_fornecedor || !nr_cnpj || !ds_email) {
    return res.status(400).json({ erro: 'Nome, CNPJ e e-mail são obrigatórios.' });
  }

  try {
    const conexao = await pool; //monta a conexao com o banco de dados
    const resultado = await conexao.request() // esperar a requisição ficar pronta
      .input('nm_fornecedor', sql.VarChar(100), nm_fornecedor)
      .input('nr_cnpj',       sql.Char(14),     nr_cnpj)
      .input('ds_email',      sql.VarChar(100), ds_email)
      .input('nr_telefone',   sql.VarChar(11),  nr_telefone || null)
      .input('is_ativo',      sql.Bit,          is_ativo ?? true) 
      .query(`
        INSERT INTO estoque.fornecedor
          (nm_fornecedor, nr_cnpj, ds_email, nr_telefone, is_ativo)
        OUTPUT INSERTED.*
        VALUES
          (@nm_fornecedor, @nr_cnpj, @ds_email, @nr_telefone, @is_ativo)
      `);

    res.status(201).json(resultado.recordset[0]); // 201 = "Criado"
  } catch (erro) {
    if (erro.number === 2627) { // violou UNIQUE (uq_fornecedor_cnpj)
      return res.status(409).json({ erro: 'Já existe um fornecedor com este CNPJ.' });
    }
    if (erro.number === 547) {  // violou um CHECK (CNPJ ou e-mail inválido)
      return res.status(400).json({ erro: 'Dados inválidos: confira o CNPJ (14 números) e o e-mail.' });
    }
    res.status(500).json({ erro: erro.message });
  }
}
);