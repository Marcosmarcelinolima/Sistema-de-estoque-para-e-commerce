// Pega o <tbody> da tabela pelo id
const tabela = document.getElementById('tabela-fornecedores');

// READ: busca os fornecedores na API e desenha a tabela
async function carregarFornecedores() {
  try {
    const resposta = await fetch('/api/fornecedores'); // GET para o nosso servidor
    const dados = await resposta.json();               // texto JSON -> objeto JS

    if (!resposta.ok) {                // status fora de 200-299
      throw new Error(dados.erro);     // usa a mensagem que a API mandou
    }

    desenharTabela(dados);
  } catch (erro) {
    tabela.innerHTML = `<tr><td colspan="6">Erro: ${erro.message}</td></tr>`;
  }
}

function desenharTabela(fornecedores) {
  tabela.innerHTML = ''; // apaga o "Carregando..."

  if (fornecedores.length === 0) {
    tabela.innerHTML = '<tr><td colspan="6">Nenhum fornecedor encontrado.</td></tr>';
    return;
  }

  for (const f of fornecedores) {
    const linha = document.createElement('tr');

    adicionarCelula(linha, f.cd_fornecedor);
    adicionarCelula(linha, f.nm_fornecedor);
    adicionarCelula(linha, f.nr_cnpj);
    adicionarCelula(linha, f.ds_email);
    adicionarCelula(linha, f.nr_telefone || '—');
    adicionarCelula(linha, f.status ? 'Ativo' : 'Inativo');

    tabela.appendChild(linha);
  }
}

function adicionarCelula(linha, texto) {
  const celula = document.createElement('td');
  celula.textContent = texto;
  linha.appendChild(celula);
}

// Quando a página abre, carrega a lista
carregarFornecedores();