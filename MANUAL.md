# 🏦 ps-banking - Manual de Funcionalidades

Sistema bancário moderno para QBCore e ESX com contas, contas a pagar e histórico de transações.

**Versão:** 1.0.4 | **Framework:** QBCore/ESX | **Licença:** MIT

---

## 🎯 O que o ps-banking faz

O ps-banking é um sistema bancário completo para servidores FiveM. Ele gerencia contas pessoais e empresariais, sistema de criação e pagamento de contas (bills), histórico de transações, transferências entre jogadores e acesso via ATMs.

---

## ⚙️ Como funciona

O sistema bancário opera através de:
- **Cliente:** Interface NUI para visualização de contas, transferências, pagamento de contas
- **Servidor:** Validação de transações, persistência no banco de dados, integração com framework
- **Banco de Dados:** Armazena contas, transações e contas a pagar

O sistema usa o ox_lib para notificações e suporte a múltiplos idiomas.

---

## 🔧 Configuração

Edite `config.lua`:

```lua
Config = {
    -- Locais de ATMs
    ATMLocations = {
        {coords = vec3(25.0, -1345.0, 29.5), heading = 0.0},
        {coords = vec3(150.0, -1000.0, 30.0), heading = 180.0}
    },
    
    -- Configurações de contas
    AccountSettings = {
        personal = true,       -- Contas pessoais
        business = true,       -- Contas empresariais
        shared = false         -- Contas compartilhadas
    },
    
    -- Limites de transação
    TransactionLimits = {
        daily = 100000,        -- Limite diário
        single = 50000         -- Limite por transação
    },
    
    -- Preferências de UI
    ShowBalance = true,
    ShowTransactionHistory = true,
    MaxHistoryEntries = 50
}
```

### Importação do Banco de Dados
Importe `ps-banking.sql` para o seu banco de dados MySQL antes de iniciar o recurso.

---

## 📤 Exports

### Criar Conta (Servidor)
```lua
exports["ps-banking"]:createBill({
    identifier = "HVZ84591",       -- Citizen ID do jogador
    description = "Conta de Utilidades",
    type = "Expense",              -- "Expense" ou "Income"
    amount = 150.00
})
```

### Obter Saldo (Servidor)
```lua
local balance = exports["ps-banking"]:getBalance(source)
```

### Transferir Dinheiro (Servidor)
```lua
exports["ps-banking"]:transferMoney(source, targetId, amount)
```

---

## 📡 Eventos

### Eventos do Cliente
| Evento | Descrição | Parâmetros |
|--------|-----------|-------------|
| `ps-banking:client:openBank` | Abrir interface bancária | None |
| `ps-banking:client:openATM` | Abrir interface de ATM | None |
| `ps-banking:client:updateBalance` | Atualizar saldo exibido | `balance` (float) |

### Eventos do Servidor
| Evento | Descrição | Parâmetros |
|--------|-----------|-------------|
| `ps-banking:server:createBill` | Criar nova conta | `src`, `billData` |
| `ps-banking:server:payBill` | Pagar conta existente | `src`, `billId` |
| `ps-banking:server:transferMoney` | Transferir dinheiro | `src`, `target`, `amount` |
| `ps-banking:server:getBalance` | Obter saldo | `src`, `cb` (callback) |
| `ps-banking:server:getTransactionHistory` | Histórico | `src`, `cb` (callback) |

---

## 🎮 Comandos

| Comando | Descrição | Permissão |
|---------|-----------|------------|
| `/bank` | Abrir interface bancária | Todos os Jogadores |
| `/atm` | Abrir interface de ATM | Todos os Jogadores |
| `/paybill [id]` | Pagar conta específica | Todos os Jogadores |

---

## 🔗 Integrações

### Frameworks Suportados
- **QBCore** - Integração completa
- **ESX** - Integração completa

### Dependências
- **qb-core OU es_extended** (obrigatório) - Framework
- **ox_lib** (obrigatório) - UI e locale
- **oxmysql** (obrigatório) - Banco de dados

### Integração com ps-dispatch
```lua
-- Alerta de assalto a banco
TriggerServerEvent('ps-dispatch:server:addCall', {
    message = 'Assalto em andamento',
    coords = GetEntityCoords(PlayerPedId()),
    jobs = {'police'}
})
```

---

## 💡 Casos de Uso

### Criar Conta para Jogador (Servidor)
```lua
RegisterServerEvent('contas:gerar', function(description, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    exports["ps-banking"]:createBill({
        identifier = Player.PlayerData.citizenid,
        description = description,
        type = "Expense",
        amount = amount
    })
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Conta Gerada',
        description = ('Conta de $%s gerada'):format(amount),
        type = 'success'
    })
end)
```

### Pagar Conta (Servidor)
```lua
RegisterServerEvent('contas:pagar', function(billId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    TriggerEvent('ps-banking:server:payBill', src, billId, function(success)
        if success then
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Sucesso',
                description = 'Conta paga com sucesso',
                type = 'success'
            })
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Erro',
                description = 'Saldo insuficiente',
                type = 'error'
            })
        end
    end)
end)
```

### Transferência entre Jogadores
```lua
RegisterServerEvent('banco:transferir', function(targetId, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if Player.PlayerData.money.cash >= amount then
        exports["ps-banking"]:transferMoney(src, targetId, amount)
    end
end)
```

### Verificar Saldo (Servidor)
```lua
local balance = exports["ps-banking"]:getBalance(source)
print(('Saldo do jogador: $%s'):format(balance))
```

---

## 💳 Tipos de Conta

### Conta Pessoal
- Gerenciada pelo jogador
- Saldo vinculado ao citizen ID
- Histórico de transações completo

### Conta Empresarial
- Vinculada a jobs/empresas
- Múltiplos usuários autorizados
- Relatórios financeiros

### Contas a Pagar (Bills)
- Geradas por serviços (água, luz, etc.)
- Pagamento parcial ou total
- Notificação automática ao gerar

---

## 🌐 Localização

Suporta sistema de locale do ox_lib. Defina o idioma no `server.cfg`:
```cfg
setr ox:locale pt-BR
```

---

## ⚠️ Solução de Problemas

### Interface não abre
- Verifique se o ox_lib está rodando
- Confirme que `ensure ps-banking` está no server.cfg
- Olhe o console do cliente (F8) para erros

### Erro de banco de dados
- Confirme que o oxmysql está rodando
- Verifique se `ps-banking.sql` foi importado
- Olhe os logs do servidor para erros SQL

### Transferência falha
- Verifique se o jogador alvo existe
- Confirme que o valor é positivo
- Verifique se não excede o limite de transação

### Contas não aparecem
- Verifique se o citizen ID está correto
- Confirme que a tabela `bank_accounts` existe
- Reinicie o recurso após importar SQL

### Saldo incorreto
- Verifique se o framework está sincronizado
- Confirme que as transações estão sendo salvas
- Veja o histórico para identificar discrepâncias

### ATM não funciona
- Verifique se o ATM está nos locais configurados
- Confirme que o jogador está perto o suficiente
- Verifique se não há conflito com outros recursos de ATM

---

## 📚 Créditos
- [Project Sloth](https://github.com/Project-Sloth)
- [Rafaell#0202](https://github.com/BachPB) - Redesign
- [BachPB](https://github.com/BachPB)
