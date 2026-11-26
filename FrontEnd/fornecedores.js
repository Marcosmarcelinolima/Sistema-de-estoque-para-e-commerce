// =====================================================================
// fornecedores.js - lógica da tela de fornecedores
//
// Fluxo: clique na tela -> função deste arquivo -> fetch na API
//        -> servidor roda o SQL -> resposta JSON -> tela atualiza
// =====================================================================


// ---------- 1. ELEMENTOS DA PÁGINA (pelo id) ----------
const tabela      = document.getElementById('tabela-fornecedores');
const form        = document.getElementById('form-fornecedor');
const painelForm  = document.getElementById('painel-form');
const tituloForm  = document.getElementById('titulo-form');
const btnNovo     = document.getElementById('btn-novo');
const btnCancelar = document.getElementById('btn-cancelar');
const mensagem    = document.getElementById('mensagem');
const filtros     = document.querySelector('.filters');
let filtroAtual   = 'ativos'; // começa mostrando os ativos


// ---------- 2. READ: carregar e desenhar a tabela ----------
async function carregarFornecedores() {
  try {
    const resposta = await fetch(`/api/fornecedores?status=${filtroAtual}`);    const dados = await resposta.json();               // texto JSON -> objeto JS

    if (!resposta.ok) {            // status fora de 200-299
      throw new Error(dados.erro); // usa a mensagem que a API mandou
    }

    desenharTabela(dados);
  } catch (erro) {
    tabela.innerHTML = `<tr><td colspan="7">Erro: ${erro.message}</td></tr>`;
  }
}

function desenharTabela(fornecedores) {
  tabela.innerHTML = ''; // apaga as linhas antigas

  if (fornecedores.length === 0) {
    tabela.innerHTML = '<tr><td colspan="7">Nenhum fornecedor encontrado.</td></tr>';
    return;
  }

  for (const f of fornecedores) {
    const linha = document.createElement('tr');
    linha.dataset.id = f.cd_fornecedor; // guarda o código na linha: <tr data-id="1">

    adicionarCelula(linha, f.cd_fornecedor);
    adicionarCelula(linha, f.nm_fornecedor);
    adicionarCelula(linha, f.nr_cnpj);
    adicionarCelula(linha, f.ds_email);
    adicionarCelula(linha, f.nr_telefone || '—');

    // Selo de situação: a API manda status = 'Ativo' ou 'Inativo' (texto).
    // Comparamos o texto, porque qualquer texto (até 'Inativo') conta como verdadeiro.
    const ativo = f.status === 'Ativo';
    const celulaStatus = document.createElement('td');
    const selo = document.createElement('span');
    selo.className   = ativo ? 'status status--active' : 'status status--inactive';
    selo.textContent = f.status;
    celulaStatus.appendChild(selo);
    linha.appendChild(celulaStatus);

    // Botões da linha (data-acao diz o que cada um faz)
    const celulaAcoes = document.createElement('td');
    celulaAcoes.className = 'actions';
    celulaAcoes.innerHTML =
      '<button class="btn btn--small" type="button" data-acao="editar">Editar</button>';
    linha.appendChild(celulaAcoes);

    tabela.appendChild(linha);
  }
}

// textContent (e não innerHTML) para dados do banco: evita executar
// código caso alguém cadastre um nome com "<script>"
function adicionarCelula(linha, texto) {
  const celula = document.createElement('td');
  celula.textContent = texto;
  linha.appendChild(celula);
}


// ---------- 3. ABRIR O FORMULÁRIO ----------

// Cadastro: formulário vazio
function abrirCadastro() {
  form.reset();                  // limpa os campos (e marca "ativo", que vem checked)
  form.cd_fornecedor.value = ''; // sem código = cadastro
  tituloForm.textContent = 'Novo fornecedor';
  painelForm.hidden = false;
  form.nm_fornecedor.focus();
}

// Edição: busca o fornecedor na API e preenche o formulário
async function abrirEdicao(id) {
  try {
    const resposta = await fetch(`/api/fornecedores/${id}`); // GET /:id
    const f = await resposta.json();
    if (!resposta.ok) throw new Error(f.erro);

    form.cd_fornecedor.value = f.cd_fornecedor; // com código = edição
    form.nm_fornecedor.value = f.nm_fornecedor;
    form.nr_cnpj.value       = f.nr_cnpj;
    form.ds_email.value      = f.ds_email;
    form.nr_telefone.value   = f.nr_telefone || '';
    form.is_ativo.checked    = f.status === 'Ativo';

    tituloForm.textContent = `Editar fornecedor #${f.cd_fornecedor}`;
    painelForm.hidden = false;
    painelForm.scrollIntoView({ behavior: 'smooth' }); // rola até o formulário
    form.nm_fornecedor.focus();
  } catch (erro) {
    mostrarMensagem(erro.message, 'erro');
  }
}

function fecharFormulario() {
  painelForm.hidden = true;
  form.reset();
}


// ---------- 4. CREATE / UPDATE: salvar ----------
async function salvar(evento) {
  evento.preventDefault(); // impede o navegador de recarregar a página

  // Monta o objeto que vira o JSON enviado à API
  const fornecedor = {
    nm_fornecedor: form.nm_fornecedor.value.trim(),
    nr_cnpj:       form.nr_cnpj.value.replace(/\D/g, ''),            // só números
    ds_email:      form.ds_email.value.trim(),
    nr_telefone:   form.nr_telefone.value.replace(/\D/g, '') || null, // vazio vira null
    is_ativo:      form.is_ativo.checked,
  };

  // O campo escondido decide: '' = cadastro (POST), '5' = edição (PUT)
  const id     = form.cd_fornecedor.value;
  const url    = id ? `/api/fornecedores/${id}` : '/api/fornecedores';
  const metodo = id ? 'PUT' : 'POST';

  try {
    const resposta = await fetch(url, {
      method: metodo,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(fornecedor), // objeto JS -> texto JSON
    });
    const dados = await resposta.json();

    if (!resposta.ok) {
      throw new Error(dados.erro); // ex.: "Já existe um fornecedor com este CNPJ..."
    }

    mostrarMensagem(
      id ? `Fornecedor #${id} atualizado com sucesso.`
         : `Fornecedor #${dados.cd_fornecedor} cadastrado com sucesso.`,
      'sucesso'
    );
    fecharFormulario();
    carregarFornecedores(); // recarrega a tabela para mostrar a mudança
  } catch (erro) {
    mostrarMensagem(erro.message, 'erro');
  }
}


// ---------- 5. MENSAGENS ----------
let timerMensagem;

// Mostra uma mensagem por 5 segundos
function mostrarMensagem(texto, tipo) {
  mensagem.textContent = texto;
  mensagem.className = `alert alert--${tipo}`;
  mensagem.hidden = false;
  clearTimeout(timerMensagem); // cancela o sumiço da mensagem anterior
  timerMensagem = setTimeout(() => { mensagem.hidden = true; }, 5000);
}


// ---------- 6. EVENTOS (o que acontece em cada clique) ----------
btnNovo.addEventListener('click', abrirCadastro);
btnCancelar.addEventListener('click', fecharFormulario);
form.addEventListener('submit', salvar);

// Um único "ouvinte" na tabela para todos os botões das linhas.
// Descobrimos qual fornecedor pelo data-id do <tr>.
tabela.addEventListener('click', (evento) => {
  const botao = evento.target.closest('button[data-acao]');
  if (!botao) return; // clicou em outro lugar da tabela

  const id = botao.closest('tr').dataset.id;
  if (botao.dataset.acao === 'editar') abrirEdicao(id);
});


// Filtro: troca o botão destacado e recarrega a lista
filtros.addEventListener('click', (evento) => {
  const chip = evento.target.closest('.chip');
  if (!chip) return;

  filtros.querySelector('.is-active').classList.remove('is-active');
  chip.classList.add('is-active');

  filtroAtual = chip.dataset.status;
  carregarFornecedores();
});

// ---------- 7. INÍCIO: quando a página abre, carrega a lista ----------
carregarFornecedores();
