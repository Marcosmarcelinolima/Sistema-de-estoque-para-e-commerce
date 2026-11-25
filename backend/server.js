const express = require('express'); // carrega a biblioteca Express
const app = express();              // cria o servidor

// ROTA: quando alguém acessar GET /rota, responda com este JSON
app.get('/rota', (req, res) => {
  res.json({ mensagem: 'Olá! O servidor está funcionando.' });
});

// Liga o servidor na porta 3000 e fica esperando requisições
app.listen(3000, () => {
  console.log('Servidor rodando em http://localhost:3000');
});