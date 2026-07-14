# ps-banking — Manual

Sistema bancário com NUI: contas pessoais e de sociedade (job/gangue), faturas, histórico de transações, transferências entre jogadores, bancos no mapa e ATMs.

---

## Sumário

1. [Dependências](#dependências)
2. [Instalação](#instalação)
3. [Configuração](#configuração)
4. [Contas](#contas)
5. [Contas de sociedade (job e gangue)](#contas-de-sociedade-job-e-gangue)
6. [Faturas](#faturas)
7. [Bancos e ATMs](#bancos-e-atms)
8. [Banco de dados](#banco-de-dados)
9. [Integrações](#integrações)
10. [Limitações conhecidas](#limitações-conhecidas)
11. [Entrypoints para outros recursos](#entrypoints-para-outros-recursos)
12. [Localização](#localização)
13. [Estrutura de arquivos](#estrutura-de-arquivos)

---

## Dependências

| Recurso | Obrigatório | Observação |
|---|---|---|
| `ox_lib` | Sim | Declarado em `dependencies`. O servidor exige **versão 3.20.0 ou superior** (`lib.checkDependency`) e aborta se for mais antiga |
| `oxmysql` | Sim | Declarado em `dependencies`. Todas as contas, faturas e transações ficam em MySQL |
| `qb-core` ou `es_extended` | Sim | O recurso detecta o framework pelo `GetResourceState` desses dois nomes. Se nenhum estiver iniciado, o recurso derruba com o erro `no_framework_found` |
| `qbx_core` | Sim | As partes específicas do fork MRI chamam exports do QBox diretamente: `GetJobs`, `GetGangs`, `GetOfflinePlayer`, `AddMoney` e `GetSource` |
| `ox_target`, `qb-target` ou `interact` | Sim | Interação com bancos e ATMs. Escolhido em `Config.TargetSystem` |
| `lb-phone` | Não | Transferência por telefone e notificação de fatura paga. Ver [Integrações](#integrações) |

**Conflito:** o manifest declara `provides { 'qb-banking', 'qb-management' }`. Não rode nenhum dos dois em paralelo — o ps-banking já responde pelos exports deles.

---

## Instalação

1. Copie a pasta `ps-banking` para `resources/`.
2. Importe o SQL:
   ```
   ps-banking.sql
   ```
3. **Adicione a coluna `identifier2`**, que o `ps-banking.sql` não cria mas o código usa em toda a lógica de faturas:
   ```sql
   ALTER TABLE `ps_banking_bills` ADD COLUMN `identifier2` VARCHAR(50) NULL AFTER `identifier`;
   ```
   Sem essa coluna, criar ou pagar qualquer fatura falha. Ver [Limitações conhecidas](#limitações-conhecidas).
4. Adicione ao `server.cfg`:
   ```
   ensure ps-banking
   ```
5. Remova o `qb-banking` e o `qb-management`, se existirem.
6. Ajuste `config.lua`: o sistema de target, os locais de banco e os valores predefinidos do ATM.

---

## Configuração

Arquivo: `config.lua`.

| Campo | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `Config.LBPhone` | bool | Sim | Habilita a opção de transferir por telefone na UI. Com `false`, só existe a transferência por ID |
| `Config.TargetSystem` | string | Sim | `ox_target`, `interact` ou qualquer outro valor (que cai no `qb-target`) |
| `Config.Currency` | tabela | — | Declarado no config, mas **não é lido por nenhum código**. A UI formata os valores em real com `toLocaleString`. Ver [Limitações conhecidas](#limitações-conhecidas) |
| `Config.BankLocations.Coords` | array de `vector3` | Sim | Posições dos bancos. Cada uma vira uma zona de interação e um blip. Vem com 8 agências padrão |
| `Config.BankLocations.Blips.name` | string | Sim | Nome do blip no mapa |
| `Config.BankLocations.Blips.sprite` | number | Sim | Sprite do blip. Padrão: `108` |
| `Config.BankLocations.Blips.color` | number | Sim | Cor do blip. Padrão: `2` |
| `Config.BankLocations.Blips.scale` | number | Sim | Tamanho do blip. Padrão: `0.55` |
| `Config.PresetATM_Amounts.Amounts` | array de number | Sim | Valores de saque/depósito rápido oferecidos no ATM. Padrão: `2000`, `5000`, `10000` |
| `Config.PresetATM_Amounts.Grid` | number | Sim | Quantos botões de valor por linha na UI do ATM |
| `Config.ATM_Animation.dict` / `.name` / `.flag` | string / string / number | Sim | Animação tocada ao abrir o ATM |
| `Config.ATM_Models` | array de string | Sim | Modelos de prop reconhecidos como caixa eletrônico. Padrão: `prop_atm_01`, `prop_atm_02`, `prop_atm_03`, `prop_fleeca_atm` |

### Cor de destaque

A UI usa a convar `inventory:color` como cor de destaque, compartilhada com o inventário:

```
setr inventory:color "#43c42f"
```

O padrão, se a convar não estiver definida, é `#43c42f`.

---

## Contas

Existem dois níveis de dinheiro no recurso, e vale entender a diferença:

- **Saldo bancário do jogador** — é o `bank` do framework (`PlayerData.money.bank` no QBCore, a conta `bank` no ESX). É o que o ATM saca e deposita.
- **Contas do ps-banking** — linhas da tabela `ps_banking_accounts`, com saldo próprio, número de cartão e lista de usuários. Funcionam como cofres compartilhados: o jogador **deposita** dinheiro do seu saldo bancário para dentro delas e **saca** de volta.

Cada conta tem:

| Campo | Descrição |
|---|---|
| `holder` | Nome da conta. Em contas de sociedade, é o nome do job ou da gangue |
| `balance` | Saldo da conta |
| `cardNumber` | Número de cartão de 16 dígitos, gerado aleatoriamente e formatado em blocos de 4 |
| `owner` | Dono: `{ name, identifier, state }` |
| `users` | Lista de usuários autorizados, cada um `{ name, identifier }` |

Pela UI, o dono pode renomear a conta, adicionar e remover usuários (por ID de servidor), depositar, sacar e apagar a conta. Usuários autorizados enxergam a conta com `owner.state = false`.

O jogador não pode se adicionar como usuário da própria conta, e não pode transferir dinheiro para si mesmo.

---

## Contas de sociedade (job e gangue)

Contas cujo `holder` é o nome de um job ou de uma gangue existentes (validado contra `exports.qbx_core:GetJobs()` e `GetGangs()`) recebem tratamento especial:

- **Criação automática.** Quando um jogador **chefe** (`job.isboss` ou `gang.isboss`) carrega o personagem, troca de job ou troca de gangue, a conta do grupo é criada se ainda não existir. Se já existir, o chefe atual passa a ser o `owner`.
- **Entrada automática.** Ao entrar em um job ou gangue, o jogador é adicionado à lista de `users` da conta do grupo.
- **Saída automática.** Ao sair, ele é removido da lista de `users` e, se era o dono, perde o `owner` da conta.
- **Proteção.** Contas de job/gangue **não podem ser criadas manualmente** pela UI nem apagadas por ela — as duas operações verificam se o `holder` é um grupo válido e recusam.

Os jobs `unemployed` e `none` são ignorados.

---

## Faturas

Faturas (`ps_banking_bills`) são cobranças pendentes ligadas a um jogador. Elas não são criadas pela UI: outros recursos as criam pelo export `createBill`.

| Campo | Descrição |
|---|---|
| `identifier` | Citizen ID de quem **deve** pagar |
| `identifier2` | Citizen ID de quem **recebe** o valor quando a fatura for paga |
| `description` | Texto exibido na UI |
| `type` | Categoria livre (o upstream usa `Expense` / `Income`) |
| `amount` | Valor da fatura |

Ao pagar, o valor é debitado do saldo bancário do devedor e creditado no do recebedor (via `exports.qbx_core:AddMoney`), duas transações são registradas no histórico (uma para cada lado) e a fatura é apagada. Se o recebedor estiver online e o `lb-phone` presente, ele recebe uma notificação no app Wallet.

A UI também tem um botão de **pagar todas as faturas de uma vez**. Atenção: esse fluxo apenas debita o total do devedor e apaga as faturas — ele **não** credita os recebedores nem registra transações individuais.

---

## Bancos e ATMs

- **Bancos** — as 8 coordenadas de `Config.BankLocations.Coords` viram zonas de interação (caixa de 2×2×2 no `ox_target`) mais um blip no mapa. Abrem a UI completa: contas, faturas, histórico, estatísticas e transferências.
- **ATMs** — os props de `Config.ATM_Models` viram alvos de interação. Abrem uma UI reduzida, com saque e depósito entre o dinheiro vivo e o saldo bancário, usando os valores rápidos de `Config.PresetATM_Amounts`. Uma animação de uso do caixa é tocada ao abrir.

O histórico de transações é preenchido automaticamente: o client escuta as mudanças de dinheiro do framework (`QBCore:Client:OnMoneyChange` ou `esx:setAccountMoney`) e reporta ao servidor toda variação no saldo `bank`, que vira uma linha em `ps_banking_transactions`.

O jogador pode apagar o próprio histórico pela UI. A tela de estatísticas mostra o total recebido e gasto nos últimos 7 dias e as 50 transações mais recentes.

---

## Banco de dados

Três tabelas, criadas por `ps-banking.sql` (mais o `ALTER` do passo 3 da instalação):

```sql
ps_banking_accounts     -- id, balance, holder, cardNumber, users (JSON), owner (JSON)
ps_banking_transactions -- id, identifier, description, type, amount, date, isIncome
ps_banking_bills        -- id, identifier, identifier2, description, type, amount, date, isPaid
```

Faturas pagas e histórico apagado são **removidos** das tabelas, não marcados — a coluna `isPaid` existe mas o fluxo de pagamento usa `DELETE`.

---

## Integrações

### ox_target / qb-target / interact

Definido em `Config.TargetSystem`. O valor `ox_target` usa `addBoxZone` para os bancos e `addModel` para os ATMs; `interact` usa `AddInteraction` e `AddModelInteraction`; qualquer outro valor cai no `qb-target`.

### lb-phone

Duas integrações, ambas condicionais:

- **Transferência por telefone.** Com `Config.LBPhone = true`, a UI oferece enviar dinheiro pelo telefone; o servidor chama `exports["lb-phone"]:AddTransaction`.
- **Notificação de fatura paga.** Ao pagar uma fatura, se quem recebe estiver online, o servidor dispara `exports["lb-phone"]:SendNotification` no app Wallet. Esta chamada **não** é protegida por `Config.LBPhone` nem por checagem de recurso — sem o `lb-phone` instalado, pagar uma fatura gera erro no console do servidor.

### qb-banking / qb-management (compatibilidade de sociedade)

O recurso registra manualmente os exports de `qb-banking`, de modo que recursos escritos para ele funcionem sem alteração:

```lua
exports['qb-banking']:AddMoney(nomeDaConta, valor, motivo)
exports['qb-banking']:RemoveMoney(nomeDaConta, valor, motivo)
exports['qb-banking']:GetAccount(nomeDaConta)
exports['qb-banking']:GetAccountBalance(nomeDaConta)
```

Todos apontam para as funções equivalentes do ps-banking. É por isso que o manifest declara `provides { 'qb-banking', 'qb-management' }`.

---

## Limitações conhecidas

Verificáveis no código, e todas relevantes na instalação:

- **`ps-banking.sql` está desatualizado.** A tabela `ps_banking_bills` não tem a coluna `identifier2`, mas `createBill` insere nela e `payBill` lê dela. É obrigatório rodar o `ALTER TABLE` do passo 3 da instalação.
- **`Config.Debug` não existe no `config.lua`.** O servidor consulta `Config.Debug` em mais de dez pontos (criação de conta de sociedade, entrada/saída de job, listagem de contas). Como o campo não está declarado, os logs ficam sempre desligados. Para ligá-los, adicione `Config.Debug = true` ao `config.lua`.
- **`Config.Currency` é decorativo.** Nenhum código Lua lê essa tabela; a UI formata os valores em real com `toLocaleString`. Mudar `lang` ou `currency` ali não altera nada.
- **`payAllBills` não paga os recebedores.** O fluxo de "pagar todas" debita o total do devedor e apaga as faturas, sem creditar os `identifier2` nem registrar as transações. O pagamento individual (`payBill`) faz as duas coisas.

---

## Entrypoints para outros recursos

Todos os exports abaixo são de **servidor**.

### Criar uma fatura

```lua
exports['ps-banking']:createBill({
    identifier  = 'ABC12345',        -- citizenid de quem paga
    identifier2 = 'XYZ98765',        -- citizenid de quem recebe
    description = 'Conta de luz',
    type        = 'Expense',
    amount      = 150.00,
})
```

### Movimentar uma conta

```lua
exports['ps-banking']:AddMoney(nomeDaConta, valor, motivo)     -- true se a conta existe
exports['ps-banking']:RemoveMoney(nomeDaConta, valor, motivo)  -- true se existe e tem saldo
```

O `nomeDaConta` é o `holder` — para uma sociedade, o nome do job ou da gangue (ex.: `police`). O motivo vira a descrição da transação no histórico do dono da conta.

### Ler contas

```lua
exports['ps-banking']:GetAccountByHolder(nomeDaConta)  -- alias: GetAccount
exports['ps-banking']:GetAccountById(id)
exports['ps-banking']:GetAccountBalance(nomeDaConta)   -- 0 se a conta não existe
```

### Criar contas e gerenciar usuários

```lua
exports['ps-banking']:CreatePlayerAccount(source, nomeDaConta, saldoInicial, usuarios)
exports['ps-banking']:AddUserToAccountByHolder(nomeDaConta, citizenId)
exports['ps-banking']:RemoveUserFromAccountByHolder(nomeDaConta, citizenId)
```

### Registrar uma transação no histórico

```lua
exports['ps-banking']:CreateBankStatement(source, nomeDaConta, valor, motivo, 'deposit')
```

O quinto argumento define o sinal: `deposit` grava como entrada, qualquer outro valor grava como saída.

---

## Localização

As strings da UI e das notificações são traduzidas via `ox_lib` locale. Os arquivos ficam em `locales/`:

| Arquivo | Idioma |
|---|---|
| `pt-br.json` | Português do Brasil |
| `pt.json` | Português |
| `en.json` | Inglês |
| `es.json` | Espanhol |
| `fr.json` | Francês |
| `de.json` | Alemão |
| `nl.json` | Holandês |
| `da.json` | Dinamarquês |
| `cs.json` | Tcheco |
| `tr.json` | Turco |

O locale ativo é definido pela convar `ox:locale` no `server.cfg`:

```
setr ox:locale "pt-br"
```

A UI busca as traduções pelo callback NUI `ps-banking:client:getLocales`, que devolve `lib.getLocales()`.

Alguns textos ligados a faturas estão fixos em português no `server/main.lua` (`Fatura recebida:`, `Fatura paga:`, o título da notificação do telefone) e não passam pelo sistema de locale.

---

## Estrutura de arquivos

```
ps-banking/
├── client/
│   └── main.lua           — zonas dos bancos, blips, targets dos ATMs, animação, callbacks NUI e
│                            sincronização de job/gangue com as contas de sociedade
├── server/
│   └── main.lua           — detecção do framework, contas, faturas, transferências, histórico,
│                            contas de sociedade e compatibilidade com os exports do qb-banking
├── html/
│   ├── index.html         — UI compilada (Svelte)
│   ├── index.js
│   └── index.css
├── web/                   — código-fonte Svelte da UI (Vite + Tailwind)
│   └── src/
│       ├── App.svelte
│       ├── components/    — Accounts, ATM, Bills, History, Overview, Stats, Main
│       ├── store/         — estado compartilhado da UI
│       └── utils/         — fetchNui e helpers
├── locales/               — 10 idiomas (pt-br, pt, en, es, fr, de, nl, da, cs, tr)
├── config.lua             — LBPhone, target, locais de banco, presets e modelos de ATM
├── ps-banking.sql         — schema das 3 tabelas (falta a coluna identifier2, ver Instalação)
└── fxmanifest.lua
```
