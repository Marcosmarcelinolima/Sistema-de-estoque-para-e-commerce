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
// ---------- CADASTRO (CREATE) ----------
const form        = document.getElementById('form-fornecedor');
const painelForm  = document.getElementById('painel-form');
const btnNovo     = document.getElementById('btn-novo');
const btnCancelar = document.getElementById('btn-cancelar');
const mensagem    = document.getElementById('mensagem');

// Botão "Novo fornecedor": limpa e mostra o formulário
btnNovo.addEventListener('click', () => {
  form.reset();
  painelForm.hidden = false;
  form.nm_fornecedor.focus();
});

// Botão "Cancelar": esconde o formulário
btnCancelar.addEventListener('click', () => {
  painelForm.hidden = true;
});

// Envio do formulário
form.addEventListener('submit', async (evento) => {
  evento.preventDefault(); // impede o navegador de recarregar a página

  // Monta o objeto que vira o JSON enviado à API
  const fornecedor = {
    nm_fornecedor: form.nm_fornecedor.value.trim(),
    nr_cnpj:       form.nr_cnpj.value.replace(/\D/g, ''),            // só números
    ds_email:      form.ds_email.value.trim(),
    nr_telefone:   form.nr_telefone.value.replace(/\D/g, '') || null, // vazio vira null
  };

  try {
    const resposta = await fetch('/api/fornecedores', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(fornecedor), // objeto JS -> texto JSON
    });
    const dados = await resposta.json();

    if (!resposta.ok) {
      throw new Error(dados.erro); // ex.: "Já existe um fornecedor com este CNPJ..."
    }

    mostrarMensagem(`Fornecedor #${dados.cd_fornecedor} cadastrado com sucesso.`, 'sucesso');
    painelForm.hidden = true;
    carregarFornecedores(); // recarrega a tabela para mostrar o novo
  } catch (erro) {
    mostrarMensagem(erro.message, 'erro');
  }
});

// Mostra uma mensagem por 5 segundos
function mostrarMensagem(texto, tipo) {
  mensagem.textContent = texto;
  mensagem.className = `alert alert--${tipo}`;
  mensagem.hidden = false;
  setTimeout(() => { mensagem.hidden = true; }, 5000);
}
// Quando a página abre, carrega a lista
carregarFornecedores();