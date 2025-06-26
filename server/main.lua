lib.versionCheck("Project-Sloth/ps-banking")
assert(lib.checkDependency("ox_lib", "3.20.0", true))

local framework = nil

if GetResourceState("es_extended") == "started" then
	framework = "ESX"
	ESX = exports["es_extended"]:getSharedObject()
elseif GetResourceState("qb-core") == "started" then
	framework = "QBCore"
	QBCore = exports["qb-core"]:GetCoreObject()
else
	return error(locale("no_framework_found"))
end

local function getPlayerIdentifier(player)
	if framework == "ESX" then
		return player.getIdentifier()
	elseif framework == "QBCore" then
		return player.PlayerData.citizenid
	end
end

local function getPlayerFromId(source)
	if framework == "ESX" then
		return ESX.GetPlayerFromId(source)
	elseif framework == "QBCore" then
		return QBCore.Functions.GetPlayer(source)
	end
end

local function getPlayerAccounts(player)
	if framework == "ESX" then
		return player.getAccount("bank").money
	elseif framework == "QBCore" then
		return player.PlayerData.money["bank"]
	end
end

local function getName(player)
	if framework == "ESX" then
		return player.getName()
	elseif framework == "QBCore" then
		return player.PlayerData.charinfo.firstname .. " " .. player.PlayerData.charinfo.lastname
	end
end

local function logTransaction(identifier, description, accountName, amount, isIncome)
	MySQL.insert.await(
		"INSERT INTO ps_banking_transactions (identifier, description, type, amount, date, isIncome) VALUES (?, ?, ?, ?, NOW(), ?)",
		{ identifier, description, accountName, amount, isIncome }
	)
end

-- Society Compat MRI
local function exportHandler(exportName, func)
    AddEventHandler(('__cfx_export_%s_%s'):format('qb-banking', exportName), function(setCB)
        setCB(func)
    end)
end

local PlayerJob = nil
local PlayerGang = nil

local function generateCardNumber()
    local rawNumber = tostring(math.random(1e15, 9e15))
    local formattedNumber = rawNumber:gsub("(%d%d%d%d)", "%1 "):sub(1, -2)
    return formattedNumber
end

local function validateGroup(group)
	local JOBS = exports.qbx_core:GetJobs()
	local GANGS = exports.qbx_core:GetGangs()
	if JOBS[group] or GANGS[group] then
		return false
	end
	return true
end

local function addMoney(accountName, amount, reason)
    local account = MySQL.query.await("SELECT * FROM ps_banking_accounts WHERE holder = ?", { accountName })
    if #account > 0 then
        MySQL.update.await(
            "UPDATE ps_banking_accounts SET balance = balance + ? WHERE holder = ?",
            { amount, accountName }
        )

        local ownerData = json.decode(account[1].owner or "{}")
        local identifier = ownerData and ownerData.identifier or nil

        if identifier then
            logTransaction(identifier, reason, accountName, amount, true)
        end

        return true
    end
    return false
end
exports("AddMoney", addMoney)
exportHandler("AddMoney", addMoney)

local function removeMoney(accountName, amount, reason)
    local account = MySQL.query.await("SELECT * FROM ps_banking_accounts WHERE holder = ?", { accountName })
    if #account > 0 and account[1].balance >= amount then
        MySQL.update.await(
            "UPDATE ps_banking_accounts SET balance = balance - ? WHERE holder = ?",
            { amount, accountName }
        )

        local ownerData = json.decode(account[1].owner or "{}")
        local identifier = ownerData and ownerData.identifier or nil

        if identifier then
            logTransaction(identifier, reason, accountName, amount, false)
        end

        return true
    end
    return false
end
exports("RemoveMoney", removeMoney)
exportHandler("RemoveMoney", removeMoney)

local function createPlayerAccount(playerId, accountName, accountBalance, accountUsers)
    local xPlayer = getPlayerFromId(playerId)

    if not xPlayer then
        return false
    end

    local cardNumber = generateCardNumber()

    local ownerData = {
        name = getName(xPlayer),
        state = true,
        identifier = getPlayerIdentifier(xPlayer)
    }

    MySQL.insert.await(
        "INSERT INTO ps_banking_accounts (balance, holder, cardNumber, users, owner) VALUES (?, ?, ?, ?, ?)",
        {
            accountBalance,
            accountName,
            cardNumber,
            json.encode(accountUsers),
            json.encode(ownerData)
        }
    )

    return true
end
exports("CreatePlayerAccount", createPlayerAccount)

local function getAccountById(accountId)
    local account = MySQL.query.await("SELECT * FROM ps_banking_accounts WHERE id = ?", { accountId })
    return account[1] or nil
end
exports("GetAccountById", getAccountById)

local function getAccountByHolder(accountName)
	local account = MySQL.query.await("SELECT * FROM ps_banking_accounts WHERE holder = ?", { accountName })
	return account[1] or nil
end
exports("GetAccountByHolder", getAccountByHolder)
exports("GetAccount", getAccountByHolder) -- provavelmente temos que preparar os dados antes de enviar
exportHandler("GetAccount", getAccountByHolder)

local function getAccountBalance(accountName)
	local account = getAccountByHolder(accountName)
	return account and account.balance or 0
end
exports("GetAccountBalance", getAccountBalance)
exportHandler("GetAccountBalance", getAccountBalance)

local function createBankStatement(playerId, account, amount, reason, statementType, accountType)
	local xPlayer = getPlayerFromId(playerId)
	if not xPlayer then
		return false
	end

	logTransaction(getPlayerIdentifier(xPlayer), reason, account, amount, statementType == "deposit")
	return true
end
exports("CreateBankStatement", createBankStatement)

local function addUserToAccountByHolder(accountName, userId)
    local account = getAccountByHolder(accountName)
    if not account then
        return false
    end
    local users = json.decode(account.users or "[]")
    table.insert(users, { identifier = userId })
    MySQL.update.await(
        "UPDATE ps_banking_accounts SET users = ? WHERE holder = ?",
        { json.encode(users), accountName }
    )
    return true
end
exports("AddUserToAccountByHolder", addUserToAccountByHolder)

local function removeUserFromAccountByHolder(accountName, userId)
    local account = getAccountByHolder(accountName)
    if not account then
        return false
    end
    local users = json.decode(account.users or "[]")
    local updatedUsers = {}
    for _, user in ipairs(users) do
        if user.identifier ~= userId then
            table.insert(updatedUsers, user)
        end
    end
    MySQL.update.await(
        "UPDATE ps_banking_accounts SET users = ? WHERE holder = ?",
        { json.encode(updatedUsers), accountName }
    )
    return true
end
exports("RemoveUserFromAccountByHolder", removeUserFromAccountByHolder)

-- Society Compat MRI

lib.callback.register("ps-banking:server:getHistory", function(source)
	local xPlayer = getPlayerFromId(source)
	local identifier = getPlayerIdentifier(xPlayer)
	local result = MySQL.query.await("SELECT * FROM ps_banking_transactions WHERE identifier = ?", { identifier })
	return result
end)

lib.callback.register("ps-banking:server:deleteHistory", function(source)
	local xPlayer = getPlayerFromId(source)
	local identifier = getPlayerIdentifier(xPlayer)
	MySQL.query.await("DELETE FROM ps_banking_transactions WHERE identifier = ?", { identifier })
	return true
end)

lib.callback.register("ps-banking:server:payAllBills", function(source)
	local xPlayer = getPlayerFromId(source)
	local identifier = getPlayerIdentifier(xPlayer)
	local result = MySQL.query.await(
		"SELECT SUM(amount) as total FROM ps_banking_bills WHERE identifier = ? AND isPaid = 0",
		{ identifier }
	)
	local totalAmount = result[1].total or 0
	local bankBalance = getPlayerAccounts(xPlayer)
	if tonumber(bankBalance) >= tonumber(totalAmount) then
		if framework == "ESX" then
			xPlayer.removeAccountMoney("bank", tonumber(totalAmount))
		elseif framework == "QBCore" then
			xPlayer.Functions.RemoveMoney("bank", tonumber(totalAmount))
		end
		MySQL.query.await("DELETE FROM ps_banking_bills WHERE identifier = ?", { identifier })
		return true
	else
		return false
	end
end)

lib.callback.register("ps-banking:server:getWeeklySummary", function(source)
	local xPlayer = getPlayerFromId(source)
	local identifier = getPlayerIdentifier(xPlayer)
	local receivedResult = MySQL.query.await(
		"SELECT SUM(amount) as totalReceived FROM ps_banking_transactions WHERE identifier = ? AND isIncome = ? AND DATE(date) >= DATE(NOW() - INTERVAL 7 DAY)",
		{ identifier, true }
	)
	local totalReceived = receivedResult[1].totalReceived or 0
	local usedResult = MySQL.query.await(
		"SELECT SUM(amount) as totalUsed FROM ps_banking_transactions WHERE identifier = ? AND isIncome = ? AND DATE(date) >= DATE(NOW() - INTERVAL 7 DAY)",
		{ identifier, false }
	)
	local totalUsed = usedResult[1].totalUsed or 0
	return {
		totalReceived = totalReceived,
		totalUsed = totalUsed,
	}
end)

lib.callback.register("ps-banking:server:transferMoney", function(source, data)
	local xPlayer = getPlayerFromId(source)
	local targetPlayer = getPlayerFromId(data.id)
	local amount = tonumber(data.amount)

	if data.id == source and data.method == "id" then
		return false, locale("cannot_send_self_money")
	end

	if xPlayer and targetPlayer and amount > 0 then
		local xPlayerBalance = getPlayerAccounts(xPlayer)
		if xPlayerBalance >= amount then
			if data.method == "id" then
				if framework == "ESX" then
					xPlayer.removeAccountMoney("bank", amount)
					targetPlayer.addAccountMoney("bank", amount)
				elseif framework == "QBCore" then
					xPlayer.Functions.RemoveMoney("bank", amount)
					targetPlayer.Functions.AddMoney("bank", amount)
				end
				return true, locale("money_sent", amount, getName(targetPlayer))
			elseif data.method == "phone" then
				exports["lb-phone"]:AddTransaction(
					targetPlayer.identifier,
					amount,
					locale("received_money", getName(xPlayer), amount)
				)
				return true, locale("money_sent", amount, getName(targetPlayer))
			end
		else
			return false, locale("no_money")
		end
	else
		return false, locale("user_not_in_city")
	end
end)

RegisterNetEvent("ps-banking:server:logClient", function(account, moneyData)
	if account.name ~= "bank" then
		return
	end

	local src = source
	local xPlayer = getPlayerFromId(src)
	local identifier = getPlayerIdentifier(xPlayer)

	local previousBankBalance = 0
	if moneyData then
		for _, data in ipairs(moneyData) do
			if data.name == "bank" then
				previousBankBalance = data.amount
				break
			end
		end
	end

	local currentBankBalance = getPlayerAccounts(xPlayer)
	local amountChange = currentBankBalance - previousBankBalance

	if amountChange ~= 0 then
		local isIncome = currentBankBalance >= previousBankBalance and true or false
		local description = locale("transaction_description")
		logTransaction(identifier, description, account.name, math.abs(amountChange), isIncome)
	end
end)

lib.callback.register("ps-banking:server:getTransactionStats", function(source)
	local xPlayer = getPlayerFromId(source)
	local identifier = getPlayerIdentifier(xPlayer)

	local result = MySQL.query.await(
		"SELECT COUNT(*) as totalCount, SUM(amount) as totalAmount FROM ps_banking_transactions WHERE identifier = ?",
		{ identifier }
	)
	local transactionData = MySQL.query.await(
		"SELECT amount, date FROM ps_banking_transactions WHERE identifier = ? ORDER BY date DESC LIMIT 50",
		{ identifier }
	)

	return {
		totalCount = result[1].totalCount,
		totalAmount = result[1].totalAmount,
		transactionData = transactionData,
	}
end)

lib.callback.register("ps-banking:server:createNewAccount", function(source, newAccount)
	local xPlayer = getPlayerFromId(source)
	if not xPlayer then
		return false
	end

    if not validateGroup(newAccount.holder) then
        return false
    end

	MySQL.insert.await(
		"INSERT INTO ps_banking_accounts (balance, holder, cardNumber, users, owner) VALUES (?, ?, ?, ?, ?)",
		{
			newAccount.balance,
			newAccount.holder,
			newAccount.cardNumber,
			json.encode(newAccount.users),
			json.encode(newAccount.owner),
		}
	)
	return true
end)

lib.callback.register("ps-banking:server:getUser", function(source)
	local xPlayer = getPlayerFromId(source)
	if not xPlayer then
		return false
	end
	return {
		name = getName(xPlayer),
		identifier = getPlayerIdentifier(xPlayer),
	}
end)

lib.callback.register("ps-banking:server:getAccounts", function(source)
	local xPlayer = getPlayerFromId(source)
	if not xPlayer then
		return false
	end
	
	local playerIdentifier = getPlayerIdentifier(xPlayer)
	local playerJob = xPlayer.PlayerData.job.name
	local playerGang = xPlayer.PlayerData.gang.name

	if Config.Debug then
		print(("[ps-banking] Buscando contas para jogador %s (Job: %s, Gang: %s)"):format(playerIdentifier, playerJob, playerGang))
	end

	local accounts = MySQL.query.await("SELECT * FROM ps_banking_accounts")
	local result = {}

	for _, account in ipairs(accounts) do
		local accountData = {
			id = account.id,
			balance = account.balance,
			holder = account.holder,
			cardNumber = account.cardNumber,
			users = json.decode(account.users),
			owner = json.decode(account.owner),
		}

		local isJobOrGangAccount = not validateGroup(accountData.holder)

		if Config.Debug then
			print(("[ps-banking] Conta ID %s pertence a %s - Conta de Job/Gang? %s"):format(accountData.id, accountData.holder, isJobOrGangAccount))
		end

		if accountData.owner and accountData.owner.identifier == playerIdentifier then
			if isJobOrGangAccount and accountData.holder ~= playerJob and accountData.holder ~= playerGang then
				if Config.Debug then
					print(("[ps-banking] REMOVENDO jogador %s como OWNER da conta %s (Job/Gang: %s)"):format(playerIdentifier, accountData.holder, accountData.holder))
				end

				accountData.owner = {}

				MySQL.update.await(
					"UPDATE ps_banking_accounts SET owner = ? WHERE id = ?",
					{ json.encode(accountData.owner), accountData.id }
				)
			else
				accountData.owner.state = true
				table.insert(result, accountData)
			end
		else
			local shouldRemove = false

			if isJobOrGangAccount and accountData.holder ~= playerJob and accountData.holder ~= playerGang then
				shouldRemove = true
			end

			for index, user in ipairs(accountData.users) do
				if user.identifier == playerIdentifier then
					if shouldRemove then
						if Config.Debug then
							print(("[ps-banking] REMOVENDO jogador %s da lista de usuários da conta %s (Job/Gang: %s)"):format(playerIdentifier, accountData.holder, accountData.holder))
						end

						table.remove(accountData.users, index)

						MySQL.update.await(
							"UPDATE ps_banking_accounts SET users = ? WHERE id = ?",
							{ json.encode(accountData.users), accountData.id }
						)
					else
						accountData.owner.state = false
						table.insert(result, accountData)
					end
					break
				end
			end
		end
	end

	if Config.Debug then
		print("[ps-banking] Contas processadas para o jogador:", json.encode(result, { indent = true }))
	end

	return result
end)


lib.callback.register("ps-banking:server:deleteAccount", function(source, accountId)
	local xPlayer = getPlayerFromId(source)
	if not xPlayer then
		return false
	end

    local account = getAccountById(accountId)
    if not account then
        return false
    end

    if not validateGroup(account.holder) then
        return false
    end

	MySQL.query.await("DELETE FROM ps_banking_accounts WHERE id = ?", { accountId })
	return true
end)

lib.callback.register("ps-banking:server:withdrawFromAccount", function(source, accountId, amount)
	local xPlayer = getPlayerFromId(source)
	if not xPlayer then
		return false
	end
	local account = MySQL.query.await("SELECT * FROM ps_banking_accounts WHERE id = ?", { accountId })
	if #account > 0 then
		local balance = account[1].balance
		if balance >= amount then
			local affectedRows = MySQL.update.await(
				"UPDATE ps_banking_accounts SET balance = balance - ? WHERE id = ?",
				{ amount, accountId }
			)
			if affectedRows > 0 then
				if framework == "ESX" then
					xPlayer.addAccountMoney("bank", amount)
				elseif framework == "QBCore" then
					xPlayer.Functions.AddMoney("bank", amount)
				end
				return true
			else
				return false
			end
		else
			return false
		end
	else
		return false
	end
end)

lib.callback.register("ps-banking:server:depositToAccount", function(source, accountId, amount)
	local xPlayer = getPlayerFromId(source)
	if not xPlayer then
		return false
	end
    local bankBalance = getPlayerAccounts(xPlayer)
	if tonumber(bankBalance) >= tonumber(amount) then
		local affectedRows = MySQL.update.await(
			"UPDATE ps_banking_accounts SET balance = balance + ? WHERE id = ?",
			{ amount, accountId }
		)
		if affectedRows > 0 then
			if framework == "ESX" then
				xPlayer.removeAccountMoney("bank", amount)
			elseif framework == "QBCore" then
				xPlayer.Functions.RemoveMoney("bank", amount)
			end
			return true
		else
			return false
		end
	else
		return false
	end
end)

lib.callback.register("ps-banking:server:addUserToAccount", function(source, accountId, userId)
	local xPlayer = getPlayerFromId(source)
	local targetPlayer = getPlayerFromId(userId)
	local promise = promise.new()
	if source == userId then
		return {
			success = false,
			message = locale("cannot_add_self"),
		}
	end
	if not xPlayer then
		return {
			success = false,
			message = locale("player_not_found"),
		}
	end
	if not targetPlayer then
		return {
			success = false,
			message = locale("target_player_not_found"),
		}
	end
	local accounts = MySQL.query.await("SELECT * FROM ps_banking_accounts WHERE id = ?", { accountId })
	if #accounts > 0 then
		local account = accounts[1]
		local users = json.decode(account.users)
		for _, user in ipairs(users) do
			if user.identifier == userId then
				return {
					success = false,
					message = locale("user_already_in_account"),
				}
			end
		end
		table.insert(users, {
			name = getName(targetPlayer),
			identifier = getPlayerIdentifier(targetPlayer),
		})
		local affectedRows = MySQL.update.await(
			"UPDATE ps_banking_accounts SET users = ? WHERE id = ?",
			{ json.encode(users), accountId }
		)
		return {
			success = affectedRows > 0,
			userName = getName(targetPlayer),
		}
	else
		return {
			success = false,
			message = locale("account_not_found"),
		}
	end
end)

lib.callback.register("ps-banking:server:removeUserFromAccount", function(source, accountId, userId)
	local xPlayer = getPlayerFromId(source)
	if not xPlayer then
		return false
	end
	local accounts = MySQL.query.await("SELECT * FROM ps_banking_accounts WHERE id = ?", { accountId })
	if #accounts > 0 then
		local account = accounts[1]
		local users = json.decode(account.users)
		local updatedUsers = {}
		for _, user in ipairs(users) do
			if user.identifier ~= userId then
				table.insert(updatedUsers, user)
			end
		end
		local affectedRows = MySQL.update.await(
			"UPDATE ps_banking_accounts SET users = ? WHERE id = ?",
			{ json.encode(updatedUsers), accountId }
		)
		return affectedRows > 0
	else
		return false
	end
end)

lib.callback.register("ps-banking:server:renameAccount", function(source, id, newName)
	local xPlayer = getPlayerFromId(source)
	if not xPlayer then
		return false
	end
	local affectedRows = MySQL.update.await("UPDATE ps_banking_accounts SET holder = ? WHERE id = ?", { newName, id })
	return affectedRows > 0
end)

lib.callback.register("ps-banking:server:ATMwithdraw", function(source, amount)
	local xPlayer = getPlayerFromId(source)
	local bankBalance = getPlayerAccounts(xPlayer)

	if bankBalance >= amount then
		if framework == "ESX" then
			xPlayer.removeAccountMoney("bank", amount)
			xPlayer.addMoney(amount)
		elseif framework == "QBCore" then
			xPlayer.Functions.RemoveMoney("bank", amount)
			xPlayer.Functions.AddMoney("cash", amount)
		end
		return true
	else
		return false
	end
end)

lib.callback.register("ps-banking:server:ATMdeposit", function(source, amount)
	local xPlayer = getPlayerFromId(source)
	local cashBalance = nil
	if framework == "ESX" then
		cashBalance = xPlayer.getMoney()
	elseif framework == "QBCore" then
		cashBalance = xPlayer.PlayerData.money["cash"]
	end

	if cashBalance >= amount then
		if framework == "ESX" then
			xPlayer.removeMoney(amount)
			xPlayer.addAccountMoney("bank", amount)
		elseif framework == "QBCore" then
			xPlayer.Functions.RemoveMoney("cash", amount)
			xPlayer.Functions.AddMoney("bank", amount)
		end
		return true
	else
		return false
	end
end)

lib.callback.register("ps-banking:server:getBills", function(source)
	local xPlayer = getPlayerFromId(source)
	local identifier = getPlayerIdentifier(xPlayer)
	local result = MySQL.query.await("SELECT * FROM ps_banking_bills WHERE identifier = ?", { identifier })
	return result
end)

lib.callback.register("ps-banking:server:payBill", function(source, billId)
	local xPlayer = getPlayerFromId(source)
	local identifier = getPlayerIdentifier(xPlayer)
	local result = MySQL.query.await(
		"SELECT * FROM ps_banking_bills WHERE id = ? AND identifier = ? AND isPaid = 0",
		{ billId, identifier }
	)
	if #result == 0 then
		return false
	end
	local bill = result[1]
	local amount = bill.amount

	local xPlayerName = xPlayer.PlayerData.charinfo.firstname ..' '.. xPlayer.PlayerData.charinfo.lastname

	local identifier2 = bill.identifier2
	local senderPlayer = exports.qbx_core:GetOfflinePlayer(identifier2)
	local senderName = senderPlayer.PlayerData.charinfo.firstname ..' '.. senderPlayer.PlayerData.charinfo.lastname
	local senderLicense = senderPlayer.PlayerData.license

	if tonumber(getPlayerAccounts(xPlayer)) >= tonumber(amount) then
		if framework == "ESX" then
			xPlayer.removeAccountMoney("bank", tonumber(amount))
		elseif framework == "QBCore" then
			xPlayer.Functions.RemoveMoney("bank", tonumber(amount))
			-- senderPlayer.Functions.AddMoney("bank", tonumber(amount))
			exports.qbx_core:AddMoney(identifier2, "bank", amount, "Fatura recebida: ".. bill.description)

			logTransaction(identifier2, "Fatura recebida: ".. bill.description, xPlayerName, amount, true)
			logTransaction(identifier, "Fatura paga: ".. bill.description, xPlayerName, amount, false)

			local senderSource = exports.qbx_core:GetSource(senderLicense)
			print(xPlayerName .. " pagou uma fatura de R$" .. amount, "ID", senderSource)
			if senderSource > 0 then 
				exports["lb-phone"]:SendNotification(senderSource, {
					app = "Wallet",
					title = "Uma fatura foi paga",
					content = xPlayerName .. " pagou uma fatura de R$" .. amount .. ".",
				})
			end
		end
		MySQL.query.await("DELETE FROM ps_banking_bills WHERE id = ?", { billId })
		return true
	else
		return false
	end
end)

function createBill(data)
	local identifier = data.identifier
	local identifier2 = data.identifier2
	local description = data.description
	local type = data.type
	local amount = data.amount

	MySQL.insert.await(
		"INSERT INTO ps_banking_bills (identifier, identifier2, description, type, amount, date, isPaid) VALUES (?, ?, ?, ?, ?, NOW(), ?)",
		{ identifier, identifier2, description, type, amount, false }
	)
end
exports("createBill", createBill)

--[[ EXAMPLE
    exports["ps-banking"]:createBill({
        identifier = "char1:df6c12c50e2712c57b1386e7103d5a372fb960a0",
        description = "Utility Bill",
        type = "Expense",
        amount = 150.00,
    })
]]

-- Society Compat MRI
local function updateAccountOwner(accountName, newOwnerIdentifier, newOwnerName)
    local account = getAccountByHolder(accountName)
    if not account then return end

    local newOwnerData = {
        name = newOwnerName,
        state = true,
        identifier = newOwnerIdentifier
    }

    MySQL.update.await(
        "UPDATE ps_banking_accounts SET owner = ? WHERE holder = ?",
        { json.encode(newOwnerData), accountName }
    )

    if Config.Debug then
        print(("[ps-banking] Conta %s agora pertence a %s (%s)"):format(accountName, newOwnerName, newOwnerIdentifier))
    end
end


local function createSocietyAccountIfMissing(source, groupName, isJob)
    local xPlayer = getPlayerFromId(source)
    if not xPlayer then return end

    local isBoss = isJob and xPlayer.PlayerData.job.isboss or xPlayer.PlayerData.gang.isboss
    local playerIdentifier = getPlayerIdentifier(xPlayer)
    local playerName = getName(xPlayer)

    local accountExists = getAccountByHolder(groupName)

    if not accountExists and isBoss then
        if Config.Debug then
            print(("[ps-banking] Criando conta para o %s %s pois %s agora é chefe."):format(
                isJob and "Job" or "Gang", groupName, playerIdentifier))
        end
        createPlayerAccount(source, groupName, 0, {})
    elseif accountExists and isBoss then
        if Config.Debug then
            print(("[ps-banking] Atualizando conta para o %s %s pois %s agora é chefe."):format(
                isJob and "Job" or "Gang", groupName, playerIdentifier))
        end
        updateAccountOwner(groupName, playerIdentifier, playerName)
    end
end


lib.callback.register("ps-banking:server:createSocietyAccount", function(source)
    local xPlayer = getPlayerFromId(source)
    if not xPlayer then
        return false
    end

    createSocietyAccountIfMissing(source, xPlayer.PlayerData.job.name, true)
    
    createSocietyAccountIfMissing(source, xPlayer.PlayerData.gang.name, false)

    return true
end)


local function removePlayerFromAccount(playerIdentifier, account)
    local accountData = {
        id = account.id,
        holder = account.holder,
        users = json.decode(account.users),
        owner = json.decode(account.owner),
    }

    local isJobOrGangAccount = not validateGroup(accountData.holder)

    if isJobOrGangAccount then
        if accountData.owner and accountData.owner.identifier == playerIdentifier then
            if Config.Debug then
                print(("[ps-banking] Removendo jogador %s como OWNER da conta %s"):format(
                    playerIdentifier, accountData.holder))
            end
            accountData.owner = {}
            MySQL.update.await("UPDATE ps_banking_accounts SET owner = ? WHERE id = ?", 
                { json.encode(accountData.owner), accountData.id })
        end

        for index, user in ipairs(accountData.users) do
            if user.identifier == playerIdentifier then
                if Config.Debug then
                    print(("[ps-banking] Removendo jogador %s da lista de usuários da conta %s"):format(
                        playerIdentifier, accountData.holder))
                end
                table.remove(accountData.users, index)
                MySQL.update.await("UPDATE ps_banking_accounts SET users = ? WHERE id = ?", 
                    { json.encode(accountData.users), accountData.id })
                break
            end
        end
    end
end

local function addPlayerToAccount(playerIdentifier, jobName)
    if jobName == "unemployed" or jobName == "none" then
        return
    end

    local account = MySQL.query.await("SELECT * FROM ps_banking_accounts WHERE holder = ?", { jobName })
    if #account > 0 then
        local accountData = account[1]
        local users = json.decode(accountData.users)

        local isUserPresent = false
        for _, user in ipairs(users) do
            if user.identifier == playerIdentifier then
                isUserPresent = true
                break
            end
        end

        if not isUserPresent then
            if Config.Debug then
                print(("[ps-banking] Adicionando jogador %s à conta %s"):format(
                    playerIdentifier, jobName))
            end
            table.insert(users, { identifier = playerIdentifier })
            MySQL.update.await("UPDATE ps_banking_accounts SET users = ? WHERE holder = ?", 
                { json.encode(users), jobName })
        end
    end
end

lib.callback.register("ps-banking:server:playerGroupInfo", function(source, data, isJob)
    local xPlayer = getPlayerFromId(source)
    if not xPlayer or not data or not data.name then
        return
    end

    local playerIdentifier = getPlayerIdentifier(xPlayer)
    local playerJob = xPlayer.PlayerData.job.name
    local playerGang = xPlayer.PlayerData.gang.name

    if Config.Debug then
        print(("[ps-banking] Atualizando contas para jogador %s (Novo %s: %s)"):format(
            playerIdentifier, isJob and "Job" or "Gang", data.name))
    end

    local accounts = MySQL.query.await("SELECT * FROM ps_banking_accounts")
    for _, account in ipairs(accounts) do
        removePlayerFromAccount(playerIdentifier, account)
    end

    createSocietyAccountIfMissing(source, data.name, isJob)

    addPlayerToAccount(playerIdentifier, data.name)

    if isJob then
        PlayerJob = data
    else
        PlayerGang = data
    end
end)


-- Society Compat MRI
