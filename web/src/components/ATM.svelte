<script lang="ts">
  import { writable } from "svelte/store";
  import { onMount } from "svelte";
  import { fetchNui } from "../utils/fetchNui";
  import { fade } from "svelte/transition";
  import { quintOut } from "svelte/easing";
  import {
    showATM,
    currentCash,
    bankBalance,
    Notify,
    type Notification,
    Locales,
    Currency,
  } from "../store/data";

  let withdrawAmounts = writable([]);
  let depositAmounts = writable([]);
  let gridColsPreset = writable(3);
  let customWithdraw = writable(0);
  let customDeposit = writable(0);

  // Initialize custom amounts but don't auto-update them
  $: if ($customDeposit === 0) customDeposit.set($currentCash);
  // Remove auto-update for customWithdraw to prevent showing wrong balance after withdrawal

  async function getAmountPresets() {
    try {
      const response = await fetchNui("ps-banking:client:getAmountPresets", {});
      const amounts = JSON.parse(response);
      withdrawAmounts.set(amounts.withdrawAmounts);
      depositAmounts.set(amounts.depositAmounts);
      gridColsPreset.set(amounts.grid);
    } catch (error) {
      console.error(error);
    }
  }

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

  async function heav(amount: number) {
    try {
      if (amount <= 0 || amount > $bankBalance) return;
      
      const response = await fetchNui("ps-banking:client:ATMwithdraw", {
        amount: amount,
      });
      
      if (response) {
        // Only update balances if transaction was successful
        // Update balances from server to ensure accuracy
        await updateBalances();
        
        // Reset custom amount
        customWithdraw.set(0);
      }
    } catch (error) {
      console.error(error);
    }
  }

  async function deposit(amount: number) {
    try {
      if (amount <= 0 || amount > $currentCash) return;
      
      const response = await fetchNui("ps-banking:client:ATMdeposit", {
        amount: amount,
      });
      
      if (response) {
        // Only update balances if transaction was successful
        // Update balances from server to ensure accuracy
        await updateBalances();
        
        // Reset custom amount
        customDeposit.set(0);
      }
    } catch (error) {
      console.error(error);
    }
  }

  async function getLocales() {
    try {
      const response = await fetchNui("ps-banking:client:getLocales", {});
      Locales.set(response);
    } catch (error) {
      console.error(error);
    }
  }

  function closeATM() {
    showATM.set(false);
    fetchNui("ps-banking:client:hideUI");
  }

  // Handle escape key
  function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Escape') {
      closeATM();
    }
  }

  onMount(() => {
    getAmountPresets();
    getLocales();
    updateBalances();
    window.addEventListener('keydown', handleKeydown);
    return () => {
      window.removeEventListener('keydown', handleKeydown);
    };
  });
</script>

<svelte:window on:keydown={handleKeydown}/>

{#if $showATM}
  <div class="fixed inset-0  z-50">
    <div class="absolute w-screen h-screen flex items-center justify-center">
      <div
        class="w-[650px] modern-card overflow-hidden"
        in:fade={{ duration: 200 }}
        out:fade={{ duration: 150 }}
      >
        <!-- Header -->
        <div class="p-4 border-b border-white/10 flex items-center justify-between">
          <div class="flex items-center space-x-3">
            <div class="w-10 h-10 bg-indigo-500 rounded-xl flex items-center justify-center">
              <i class="fas fa-credit-card text-white text-lg"></i>
            </div>
            <div>
                    <h1 class="text-lg font-semibold text-white">{$Locales.atm}</h1>
      <p class="text-sm text-white/50">{$Locales.quick_management}</p>
            </div>
          </div>
          <button
            class="w-8 h-8 flex items-center justify-center rounded-lg bg-white/5 hover:bg-white/10 transition-colors text-white/50 hover:text-white/80"
            on:click={closeATM}
          >
            <i class="fas fa-times text-lg"></i>
          </button>
        </div>

        <div class="p-4 space-y-4">
          <!-- Balance Cards -->
          <div class="grid grid-cols-2 gap-4">
            <div class="bg-black/20 border border-white/10 rounded-lg p-4">
              <div class="flex items-center space-x-2 mb-1">
                <i class="fas fa-wallet text-green-400 text-lg"></i>
                <span class="text-white/80">{$Locales.cash}</span>
              </div>
              <p class="text-xl font-bold text-white">
                R$ {$currentCash.toLocaleString()}
              </p>
            </div>

            <div class="bg-black/20 border border-white/10 rounded-lg p-4">
              <div class="flex items-center space-x-2 mb-1">
                <i class="fas fa-university text-blue-400 text-lg"></i>
                <span class="text-white/80">{$Locales.bank_balance}</span>
              </div>
              <p class="text-xl font-bold text-white">
                R$ {$bankBalance.toLocaleString()}
              </p>
            </div>
          </div>

          <!-- Quick Actions -->
          <div class="grid grid-cols-3 gap-2">
            {#each $withdrawAmounts as amount}
              <button
                class="bg-black/20 border border-white/10 hover:bg-white/5 transition-colors rounded-lg p-3 text-center group relative overflow-hidden"
                on:click={() => heav(amount)}
              >
                <div class="absolute inset-0 bg-red-500/10 opacity-0 group-hover:opacity-100 transition-opacity"></div>
                <i class="fas fa-arrow-down text-red-400 mr-2"></i>
                <span class="text-white/80">R$ {amount.toLocaleString()}</span>
              </button>
            {/each}
          </div>

          <div class="grid grid-cols-3 gap-2">
            {#each $depositAmounts as amount}
              <button
                class="bg-black/20 border border-white/10 hover:bg-white/5 transition-colors rounded-lg p-3 text-center group relative overflow-hidden"
                on:click={() => deposit(amount)}
              >
                <div class="absolute inset-0 bg-green-500/10 opacity-0 group-hover:opacity-100 transition-opacity"></div>
                <i class="fas fa-arrow-up text-green-400 mr-2"></i>
                <span class="text-white/80">R$ {amount.toLocaleString()}</span>
              </button>
            {/each}
          </div>

          <!-- Custom Amount Inputs -->
          <div class="grid grid-cols-2 gap-4">
            <div class="bg-black/20 border border-white/10 rounded-lg p-4">
              <div class="flex items-center space-x-2 mb-2">
                <i class="fas fa-arrow-down text-red-400"></i>
                <span class="text-white/80">{$Locales.withdraw_amount}</span>
              </div>
              <div class="flex space-x-2">
                <input
                  type="number"
                  bind:value={$customWithdraw}
                  class="w-full bg-black/30 text-white px-3 py-2 rounded-lg border border-white/10 focus:outline-none focus:border-white/20 focus:ring-1 focus:ring-red-500/20"
                  placeholder={$Locales.enter_amount}
                  min="0"
                  max={$bankBalance}
                />
                <button
                  class="px-6 py-2 bg-red-500/20 hover:bg-red-500/30 transition-colors rounded-lg text-white relative overflow-hidden group flex items-center justify-center text-center min-w-[100px]"
                  on:click={() => heav($customWithdraw)}
                  disabled={$customWithdraw <= 0 || $customWithdraw > $bankBalance}
                >
                  <div class="absolute inset-0 bg-red-500/10 opacity-0 group-hover:opacity-100 transition-opacity"></div>
                  {$Locales.submit}
                </button>
              </div>
            </div>

            <div class="bg-black/20 border border-white/10 rounded-lg p-4">
              <div class="flex items-center space-x-2 mb-2">
                <i class="fas fa-arrow-up text-green-400"></i>
                <span class="text-white/80">{$Locales.deposit_amount}</span>
              </div>
              <div class="flex space-x-2">
                <input
                  type="number"
                  bind:value={$customDeposit}
                  class="w-full bg-black/30 text-white px-3 py-2 rounded-lg border border-white/10 focus:outline-none focus:border-white/20 focus:ring-1 focus:ring-green-500/20"
                  placeholder={$Locales.enter_amount}
                  min="0"
                  max={$currentCash}
                />
                <button
                  class="px-6 py-2 bg-green-500/20 hover:bg-green-500/30 transition-colors rounded-lg text-white relative overflow-hidden group flex items-center justify-center text-center min-w-[100px]"
                  on:click={() => deposit($customDeposit)}
                  disabled={$customDeposit <= 0 || $customDeposit > $currentCash}
                >
                  <div class="absolute inset-0 bg-green-500/10 opacity-0 group-hover:opacity-100 transition-opacity"></div>
                  {$Locales.submit}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
{/if}
