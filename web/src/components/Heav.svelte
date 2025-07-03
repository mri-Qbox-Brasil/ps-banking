<script lang="ts">
  import { writable } from "svelte/store";
  import { slide } from "svelte/transition";
  import { quintOut } from "svelte/easing";
  import { fetchNui } from "../utils/fetchNui";
  import {
    Notify,
    currentCash,
    bankBalance,
    Locales,
    Currency,
  } from "../store/data";

  let withdrawAmount = writable(0);
  $: newBank = $bankBalance - $withdrawAmount;

  async function updateBalances() {
    try {
      const response = await fetchNui("ps-banking:client:getMoneyTypes", {});
      const bank = response.find(
        (item: { name: string }) => item.name === "bank"
      );
      const cash = response.find(
        (item: { name: string }) => item.name === "cash"
      );
      if (bank) {
        bankBalance.set(bank.amount);
      }
      if (cash) {
        currentCash.set(cash.amount);
      }
    } catch (error) {
      console.error(error);
    }
  }

  async function handleWithdraw() {
    if ($bankBalance < $withdrawAmount) {
      Notify(
        `${$Locales.withdraw_error} ${$withdrawAmount.toLocaleString(
          $Currency.lang,
          {
            style: "currency",
            currency: $Currency.currency,
            minimumFractionDigits: 0,
          }
        )}`,
        $Locales.error,
        "coins"
      );
    } else {
      const response = await fetchNui("ps-banking:client:ATMwithdraw", {
        amount: $withdrawAmount,
      });
      
      if (response) {
        Notify(
          `${$Locales.withdraw_success} ${$withdrawAmount.toLocaleString(
            $Currency.lang,
            {
              style: "currency",
              currency: $Currency.currency,
              minimumFractionDigits: 0,
            }
          )}`,
          $Locales.withdraw_success,
          "coins"
        );
        
        // Update balances from server to ensure accuracy
        await updateBalances();
        withdrawAmount.set(0);
      } else {
        Notify(
          `${$Locales.withdraw_error}`,
          $Locales.error,
          "coins"
        );
      }
    }
  }
</script>

<div class="h-full flex flex-col p-8 overflow-y-auto">
  <!-- Page Header -->
  <div class="flex items-center justify-between mb-8">
    <div>
      <h1 class="text-3xl font-bold text-white mb-2">{$Locales.withdraw}</h1>
      <p class="text-white/60">{$Locales.withdraw_money_from_account}</p>
    </div>
    <div class="flex items-center space-x-4">
      <div class="modern-card px-4 py-2">
        <div class="flex items-center space-x-2">
          <div class="w-2 h-2 bg-red-400 rounded-full animate-pulse"></div>
          <span class="text-sm text-white/80">{$Locales.withdraw_status}</span>
        </div>
      </div>
    </div>
  </div>

  <!-- Withdraw Form -->
  <div class="max-w-2xl mx-auto w-full">
    <div class="grid gap-8">
      <!-- Current Balance Card -->
      <div class="modern-card p-6">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-4">
            <div class="w-12 h-12 bg-blue-500/20 rounded-xl flex items-center justify-center">
              <i class="fas fa-university text-blue-400 text-lg"></i>
            </div>
            <div>
              <p class="text-white/60 text-sm">{$Locales.bank_balance}</p>
              <p class="text-2xl font-bold text-white">
                {#if $bankBalance >= 1000000}
                  R$ {($bankBalance / 1000000).toFixed(1)}M
                {:else if $bankBalance >= 1000}
                  R$ {($bankBalance / 1000).toFixed(1)}K
                {:else}
                  R$ {$bankBalance.toLocaleString()}
                {/if}
              </p>
            </div>
          </div>
        </div>
      </div>

      <!-- Withdraw Amount Input -->
      <div class="modern-card p-6">
        <label class="block text-white/80 text-sm font-medium mb-4">{$Locales.amount}</label>
        <div class="relative">
          <div class="absolute left-4 top-1/2 transform -translate-y-1/2 text-white/40">
            <i class="fas fa-dollar-sign"></i>
          </div>
          <input
            type="number"
            class="w-full bg-white/5 text-white text-xl font-semibold pl-12 pr-4 py-4 rounded-xl border border-white/10 focus:outline-none focus:border-red-500/50 transition-colors"
            placeholder={$Locales.enter_amount}
            bind:value={$withdrawAmount}
            max={$bankBalance}
            min="0"
          />
        </div>
        
        <!-- Quick Amount Buttons -->
        <div class="grid grid-cols-4 gap-3 mt-4">
          <button
            class="px-3 py-2 bg-white/5 rounded-lg text-white/70 hover:bg-white/10 transition-colors text-sm"
            on:click={() => withdrawAmount.set(Math.floor($bankBalance * 0.25))}
          >
            25%
          </button>
          <button
            class="px-3 py-2 bg-white/5 rounded-lg text-white/70 hover:bg-white/10 transition-colors text-sm"
            on:click={() => withdrawAmount.set(Math.floor($bankBalance * 0.5))}
          >
            50%
          </button>
          <button
            class="px-3 py-2 bg-white/5 rounded-lg text-white/70 hover:bg-white/10 transition-colors text-sm"
            on:click={() => withdrawAmount.set(Math.floor($bankBalance * 0.75))}
          >
            75%
          </button>
          <button
            class="px-3 py-2 bg-white/5 rounded-lg text-white/70 hover:bg-white/10 transition-colors text-sm"
            on:click={() => withdrawAmount.set($bankBalance)}
          >
            {$Locales.all}
          </button>
        </div>
      </div>

      <!-- New Balance Preview -->
      <div class="modern-card p-6">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-4">
            <div class="w-12 h-12 bg-green-500/20 rounded-xl flex items-center justify-center">
              <i class="fas fa-wallet text-green-400 text-lg"></i>
            </div>
            <div>
              <p class="text-white/60 text-sm">{$Locales.new_bank}</p>
              <p class="text-2xl font-bold text-white">
                {#if newBank >= 1000000}
                  R$ {(newBank / 1000000).toFixed(1)}M
                {:else if newBank >= 1000}
                  R$ {(newBank / 1000).toFixed(1)}K
                {:else}
                  R$ {newBank.toLocaleString()}
                {/if}
              </p>
            </div>
          </div>
          <div class="text-right">
            <p class="text-white/60 text-sm">{$Locales.you_will_receive}</p>
            <p class="text-xl font-bold text-red-400">
                              {#if $withdrawAmount >= 1000000}
                  R$ {($withdrawAmount / 1000000).toFixed(1)}M
                {:else if $withdrawAmount >= 1000}
                  R$ {($withdrawAmount / 1000).toFixed(1)}K
                {:else}
                  R$ {$withdrawAmount.toLocaleString()}
                {/if}
            </p>
          </div>
        </div>
      </div>

      <!-- Withdraw Button -->
      <div class="modern-card p-6">
        <button
          class="w-full action-button py-4 text-lg font-semibold bg-red-500/10 border-red-500/30 hover:bg-red-500/20 disabled:opacity-50 disabled:cursor-not-allowed"
          on:click={handleWithdraw}
          disabled={$withdrawAmount <= 0 || $withdrawAmount > $bankBalance}
        >
          <i class="fas fa-arrow-down mr-3"></i>
          {$Locales.withdraw_button}
        </button>
        
        {#if $withdrawAmount > $bankBalance}
          <p class="text-red-400 text-sm mt-3 text-center">
            <i class="fas fa-exclamation-triangle mr-2"></i>
            Insufficient funds
          </p>
        {/if}
      </div>
    </div>
  </div>
</div>
