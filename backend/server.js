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
            .query('SELECT COUNT (*) AS total FROM estoque.Fornecedor where is_ativo = 1'); // executa a consulta SQL
            res.json(resultado.recordset[0]); // envia o resultado da consulta como JSON
    } catch (erro) {
        res.status(500).json({ erro: erro.message }); // envia o erro como JSON para visualizar
    }
});



//C


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
      return res.status(409).json({ erro: 'Já existe um fornecedor com este CNPJ. (Ele pode estar inativo)' });
    }
    if (erro.number === 547) {  // violou um CHECK (CNPJ ou e-mail inválido)
      return res.status(400).json({ erro: 'Dados inválidos: confira o CNPJ (14 números) e o e-mail.' });
    }
    res.status(500).json({ erro: erro.message });
  }
}
);



//R



//ROTA DE LEITURA DE FORNECEDORES POR ID - LETRA R DO CRUD
app.get('/api/fornecedores/:id', async (req, res) => {
    try {
        const conexao = await pool;
        const resultado = await conexao.request()
            .input('id', sql.Int, req.params.id) 
            // adiciona o parâmetro de entrada para a consulta, ou seja, quando a rota recebe /api/fornecedores/1, o valor 1 será passado como parâmetro para a consulta SQL retornar o id 1

//rota de busca por id NÃO depende de status, pois o id é único e não se repete, então não faz sentido filtrar por status.
            .query('SELECT cd_fornecedor, nm_fornecedor, nr_cnpj, ds_email, nr_telefone FROM estoque.Fornecedor WHERE cd_fornecedor = @id'); // executa a consulta SQL

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


// ROTA DE LEITURA DE FORNECEDORES - filtro opcional por status (query string ?status=)
//   /api/fornecedores                   -> só ativos (padrão)
//   /api/fornecedores?status=ativos     -> só ativos
//   /api/fornecedores?status=inativos   -> só inativos
//   /api/fornecedores?status=todos      -> todos
//   qualquer outro valor                -> erro 400


app.get('/api/fornecedores', async (req, res) => {
  const status = req.query.status || 'ativos'; // ?status=... (padrão: ativos)

  // Traduz o texto da URL para o valor da coluna is_ativo
  const mapa = { ativos: 1, inativos: 0, todos: null };
  if (!(status in mapa)) {
    return res.status(400).json({ erro: 'Use status=ativos, inativos ou todos.' });
  }

  try {
    const conexao = await pool;
    const resultado = await conexao.request()
      .input('ativo', sql.Bit, mapa[status])
      .query(`
        SELECT cd_fornecedor, nm_fornecedor, nr_cnpj,
               ds_email, nr_telefone, 
               case is_ativo when 1 then 'Ativo' else 'Inativo' end as status
        FROM estoque.fornecedor
        WHERE (@ativo IS NULL OR is_ativo = @ativo)
        ORDER BY cd_fornecedor
      `);
    res.json(resultado.recordset); // lista, mesmo que vazia
  } catch (erro) {
    res.status(500).json({ erro: erro.message });
  }
});




//U




app.put('/api/fornecedores/:id', async (req, res) => { //chamando pelo id do fornecedor, que é passado na URL
  const { nm_fornecedor, nr_cnpj, ds_email, nr_telefone, is_ativo } = req.body; // Pega os campos do corpo da requisição

  if (!nm_fornecedor || !nr_cnpj || !ds_email) { // Validação mínima: campos obrigatórios
    return res.status(400).json({ erro: 'Nome, CNPJ e e-mail são obrigatórios.' });
  }

  try {
    const conexao = await pool; //monta a conexao com o banco de dados
    const resultado = await conexao.request() // aguardar a requisição ficar pronta
      .input('id',            sql.Int,          req.params.id) //aplica valores
      .input('nm_fornecedor', sql.VarChar(100), nm_fornecedor)
      .input('nr_cnpj',       sql.Char(14),     nr_cnpj)
      .input('ds_email',      sql.VarChar(100), ds_email)
      .input('nr_telefone',   sql.VarChar(11),  nr_telefone || null)
      .input('is_ativo',      sql.Bit,          is_ativo ?? true) 
      .query(` 
        UPDATE estoque.fornecedor 
        SET nm_fornecedor = @nm_fornecedor,
            nr_cnpj       = @nr_cnpj,
            ds_email      = @ds_email,
            nr_telefone   = @nr_telefone,
            is_ativo      = @is_ativo
        OUTPUT INSERTED.*
        WHERE cd_fornecedor = @id
      `); // executa a consulta SQL para atualizar o fornecedor com o id passado na URL

    if (resultado.recordset.length === 0) { // se não encontrou o fornecedor com o id passado na URL retorna erro
      return res.status(404).json({ erro: 'Fornecedor não encontrado.' }); 
    }

    res.json(resultado.recordset[0]); // 200 = OK, com os dados já atualizados
  } catch (erro) {
    if (erro.number === 2627) { // Violação de PRIMARY KEY ou UNIQUE KEY do fornecedor 
      return res.status(409).json({ erro: 'Este CNPJ já pertenca à outro fornecedor.' });
    }
    if (erro.number === 547) {
      return res.status(400).json({ erro: 'Dados inválidos: confira o CNPJ (14 números) e o e-mail.' });
    }
    res.status(500).json({ erro: erro.message });
  }
}
);



//D



// DELETE: exclui um fornecedor
app.delete('/api/fornecedores/:id', async (req, res) => {
  try {
    const conexao = await pool;
    const resultado = await conexao.request()
      .input('id', sql.Int, req.params.id)
      .query(`
        DELETE FROM estoque.fornecedor
        WHERE cd_fornecedor = @id
      `);

    if (resultado.rowsAffected[0] === 0) {
      return res.status(404).json({ erro: 'Fornecedor não encontrado.' });
    }

    res.status(200).json({ mensagem: 'Fornecedor excluído com sucesso.' }); // 200 = deu certo, com conteúdo para devolver

} 

catch (erro) 
{
    if (erro.number === 547) { // tem produto vinculado? Produto nao pode apontar para fornecedor nulo. 
        try {
            const conexao = await pool;
            const resultado = await conexao.request()
                .input('id', sql.Int, req.params.id)
                .query(`
                    UPDATE estoque.fornecedor
                    SET is_ativo = 0
                    WHERE cd_fornecedor = @id
                `);

        return res.status(200).json({
            acao: 'Fornecedor desativado',
            mensagem: 'Fornecedor possui produtos vinculados. O fornecedor foi desativado ao invés de ser excluído.',
        }
        );
    } catch (erro2) {
        return res.status(500).json({ erro: erro2.message });
    }
}
res.status(500).json({ erro: erro.message });
}
}  
);