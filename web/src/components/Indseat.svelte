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

  let depositAmount = writable(0);
  $: newBank = $bankBalance + $depositAmount;

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

  async function handleDeposit() {
    if ($currentCash < $depositAmount) {
      Notify(
        `${$Locales.deposit_error} ${$depositAmount.toLocaleString(
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
      const response = await fetchNui("ps-banking:client:ATMdeposit", {
        amount: $depositAmount,
      });
      
      if (response) {
        Notify(
          `${$Locales.deposit_success} ${$depositAmount.toLocaleString(
            $Currency.lang,
            {
              style: "currency",
              currency: $Currency.currency,
              minimumFractionDigits: 0,
            }
          )}`,
          $Locales.deposit_success,
          "coins"
        );
        
        // Update balances from server to ensure accuracy
        await updateBalances();
        depositAmount.set(0);
      } else {
        Notify(
          `${$Locales.deposit_error}`,
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
      <h1 class="text-3xl font-bold text-white mb-2">{$Locales.deposit}</h1>
      <p class="text-white/60">{$Locales.deposit_cash_into_account}</p>
    </div>
    <div class="flex items-center space-x-4">
      <div class="modern-card px-4 py-2">
        <div class="flex items-center space-x-2">
          <div class="w-2 h-2 bg-green-400 rounded-full animate-pulse"></div>
          <span class="text-sm text-white/80">{$Locales.deposit_status}</span>
        </div>
      </div>
    </div>
  </div>

  <!-- Deposit Form -->
  <div class="max-w-2xl mx-auto w-full">
    <div class="grid gap-8">
      <!-- Current Cash Card -->
      <div class="modern-card p-6">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-4">
            <div class="w-12 h-12 bg-green-500/20 rounded-xl flex items-center justify-center">
              <i class="fas fa-wallet text-green-400 text-lg"></i>
            </div>
            <div>
              <p class="text-white/60 text-sm">{$Locales.cash_on_hand}</p>
              <p class="text-2xl font-bold text-white">
                {#if $currentCash >= 1000000}
                  R$ {($currentCash / 1000000).toFixed(1)}M
                {:else if $currentCash >= 1000}
                  R$ {($currentCash / 1000).toFixed(1)}K
                {:else}
                  R$ {$currentCash.toLocaleString()}
                {/if}
              </p>
            </div>
          </div>
        </div>
      </div>

      <!-- Deposit Amount Input -->
      <div class="modern-card p-6">
        <label class="block text-white/80 text-sm font-medium mb-4">{$Locales.amount}</label>
        <div class="relative">
          <div class="absolute left-4 top-1/2 transform -translate-y-1/2 text-white/40">
            <i class="fas fa-dollar-sign"></i>
          </div>
          <input
            type="number"
            class="w-full bg-white/5 text-white text-xl font-semibold pl-12 pr-4 py-4 rounded-xl border border-white/10 focus:outline-none focus:border-green-500/50 transition-colors"
            placeholder={$Locales.enter_amount}
            bind:value={$depositAmount}
            max={$currentCash}
            min="0"
          />
        </div>
        
        <!-- Quick Amount Buttons -->
        <div class="grid grid-cols-4 gap-3 mt-4">
          <button
            class="px-3 py-2 bg-white/5 rounded-lg text-white/70 hover:bg-white/10 transition-colors text-sm"
            on:click={() => depositAmount.set(Math.floor($currentCash * 0.25))}
          >
            25%
          </button>
          <button
            class="px-3 py-2 bg-white/5 rounded-lg text-white/70 hover:bg-white/10 transition-colors text-sm"
            on:click={() => depositAmount.set(Math.floor($currentCash * 0.5))}
          >
            50%
          </button>
          <button
            class="px-3 py-2 bg-white/5 rounded-lg text-white/70 hover:bg-white/10 transition-colors text-sm"
            on:click={() => depositAmount.set(Math.floor($currentCash * 0.75))}
          >
            75%
          </button>
          <button
            class="px-3 py-2 bg-white/5 rounded-lg text-white/70 hover:bg-white/10 transition-colors text-sm"
            on:click={() => depositAmount.set($currentCash)}
          >
            {$Locales.all}
          </button>
        </div>
      </div>

      <!-- New Balance Preview -->
      <div class="modern-card p-6">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-4">
            <div class="w-12 h-12 bg-blue-500/20 rounded-xl flex items-center justify-center">
              <i class="fas fa-university text-blue-400 text-lg"></i>
            </div>
            <div>
              <p class="text-white/60 text-sm">{$Locales.new_bank_balance}</p>
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
            <p class="text-white/60 text-sm">{$Locales.depositing}</p>
            <p class="text-xl font-bold text-green-400">
                              {#if $depositAmount >= 1000000}
                  R$ {($depositAmount / 1000000).toFixed(1)}M
                {:else if $depositAmount >= 1000}
                  R$ {($depositAmount / 1000).toFixed(1)}K
                {:else}
                  R$ {$depositAmount.toLocaleString()}
                {/if}
            </p>
          </div>
        </div>
      </div>

      <!-- Deposit Button -->
      <div class="modern-card p-6">
        <button
          class="w-full action-button py-4 text-lg font-semibold bg-green-500/10 border-green-500/30 hover:bg-green-500/20 disabled:opacity-50 disabled:cursor-not-allowed"
          on:click={handleDeposit}
          disabled={$depositAmount <= 0 || $depositAmount > $currentCash}
        >
          <i class="fas fa-arrow-up mr-3"></i>
          {$Locales.deposit_button}
        </button>
        
        {#if $depositAmount > $currentCash}
          <p class="text-red-400 text-sm mt-3 text-center">
            <i class="fas fa-exclamation-triangle mr-2"></i>
            Insufficient cash
          </p>
        {/if}
      </div>
    </div>
  </div>
</div>
