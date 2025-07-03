<script lang="ts">
  import { writable } from "svelte/store";
  import { onMount } from "svelte";
  import { quintOut } from "svelte/easing";
  import { slide, fade, scale } from "svelte/transition";
  import { fetchNui } from "../utils/fetchNui";
  import {
    showOverview,
    showBills,
    showHistory,
    notifications,
    Bills,
    Notify,
    Transactions,
    Locales,
    Currency,
    type Notification,
  } from "../store/data";

  let transactions = Transactions;
  let searchQuery = writable("");
  let showDeleteAllModal = writable(false);

  $: filteredTransactions = $transactions.filter(
    (transaction) =>
      transaction.description
        .toLowerCase()
        .includes($searchQuery.toLowerCase()) ||
      transaction.type.toLowerCase().includes($searchQuery.toLowerCase())
  );

  function confirmDeleteAllTransactions() {
    showDeleteAllModal.set(true);
  }

  async function deleteAllTransactions() {
    if ($transactions.length === 0) {
      Notify($Locales.history_empty, $Locales.error, "file-invoice");
      showDeleteAllModal.set(false);
    } else {
      transactions.set([]);
      showDeleteAllModal.set(false);
      Notify($Locales.all_history_deleted, $Locales.success, "file-invoice");
      try {
        const history = await fetchNui("ps-banking:client:deleteHistory", {});
        transactions.set([]);
      } catch (error) {
        console.error(error);
      }
    }
  }

  function formatDate(dateString: string) {
    const options: Intl.DateTimeFormatOptions = {
      year: "numeric",
      month: "numeric",
      day: "numeric",
    };
    return new Date(dateString).toLocaleDateString(undefined, options);
  }

  onMount(async () => {
    try {
      const history = await fetchNui("ps-banking:client:getHistory", {});
      transactions.set(history);
    } catch (error) {
      console.error(error);
    }
  });
</script>

<div class="h-full flex flex-col p-8 overflow-y-auto">
  <!-- Page Header -->
  <div class="flex items-center justify-between mb-8">
    <div>
      <h1 class="text-3xl font-bold text-white mb-2">{$Locales.history}</h1>
      <p class="text-white/60">{$Locales.view_complete_transaction_history}</p>
    </div>
    <div class="flex items-center space-x-4">
      <div class="modern-card px-4 py-2">
        <div class="flex items-center space-x-2">
          <i class="fas fa-receipt text-blue-400"></i>
          <span class="text-sm text-white/80">{filteredTransactions.length} {$Locales.transactions_count}</span>
        </div>
      </div>
      <button
        class="action-button flex items-center space-x-2 bg-red-500/10 border-red-500/30 hover:bg-red-500/20"
        on:click={confirmDeleteAllTransactions}
      >
        <i class="fas fa-trash-alt text-red-400"></i>
        <span class="text-red-400">{$Locales.delete_all_transactions}</span>
      </button>
    </div>
  </div>

  <!-- Search Bar -->
  <div class="mb-8">
    <div class="modern-card p-4">
      <div class="relative">
        <i class="fas fa-search absolute left-4 top-1/2 transform -translate-y-1/2 text-white/40"></i>
        <input
          type="text"
          class="w-full bg-transparent text-white pl-12 pr-4 py-3 focus:outline-none placeholder-white/40"
          placeholder="{$Locales.search_transactions}"
          bind:value={$searchQuery}
        />
      </div>
    </div>
  </div>

  <!-- Transactions List -->
  <div class="grid gap-4">
    {#if filteredTransactions.length > 0}
      {#each filteredTransactions as transaction (transaction.id)}
        <div
          class="modern-card modern-card-hover p-6"
          in:fade={{ duration: 300 }}
          out:slide={{ duration: 300 }}
        >
          <div class="flex items-center justify-between">
            <div class="flex items-center space-x-4 flex-1">
              <div class={`w-12 h-12 rounded-xl flex items-center justify-center ${
                transaction.isIncome 
                  ? 'bg-green-500/20' 
                  : 'bg-red-500/20'
              }`}>
                <i class={`fas ${
                  transaction.isIncome 
                    ? 'fa-arrow-down text-green-400' 
                    : 'fa-arrow-up text-red-400'
                } text-lg`}></i>
              </div>
              
              <div class="flex-1 min-w-0">
                <div class="flex items-center space-x-2 mb-1">
                  <h3 class="text-white font-semibold truncate">{transaction.description}</h3>
                  <span class="text-white/50 text-sm">#{transaction.id}</span>
                </div>
                <div class="flex items-center space-x-4 text-sm text-white/60">
                  <span>{transaction.type}</span>
                  <span>{formatDate(transaction.date)}</span>
                </div>
              </div>
            </div>

            <div class="text-right">
              <span class={`text-lg font-bold ${transaction.isIncome ? "text-green-400" : "text-red-400"}`}>
                {transaction.isIncome ? "+" : "-"}
                {#if transaction.amount >= 1000000}
                  R$ {(transaction.amount / 1000000).toFixed(1)}M
                {:else if transaction.amount >= 1000}
                  R$ {(transaction.amount / 1000).toFixed(1)}K
                {:else}
                  R$ {transaction.amount.toLocaleString()}
                {/if}
              </span>
              <div class="text-xs text-white/50 mt-1">
                {transaction.isIncome ? $Locales.received : $Locales.sent}
              </div>
            </div>
          </div>
        </div>
      {/each}
    {:else}
      <div class="modern-card p-12 text-center">
        <i class="fas fa-history text-white/30 text-5xl mb-4"></i>
        <h3 class="text-xl font-semibold text-white mb-2">{$Locales.no_transactions_found}</h3>
        <p class="text-white/60">
          {$searchQuery ? $Locales.no_transactions_match_search : $Locales.transaction_history_empty}
        </p>
      </div>
    {/if}
  </div>
</div>

<!-- Delete Confirmation Modal -->
{#if $showDeleteAllModal}
  <div class="modal-backdrop fixed inset-0 flex items-center justify-center z-50">
    <div
      class="modern-card p-8 w-full max-w-md mx-4"
      in:scale={{ duration: 300, easing: quintOut }}
      out:scale={{ duration: 250, easing: quintOut }}
    >
      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center space-x-3">
          <div class="w-12 h-12 bg-red-500/20 rounded-xl flex items-center justify-center">
            <i class="fas fa-exclamation-triangle text-red-400 text-xl"></i>
          </div>
          <h2 class="text-2xl font-bold text-white">{$Locales.are_you_sure}</h2>
        </div>
      </div>

      <p class="text-white/70 mb-6">
        {$Locales.delete_confirmation}
      </p>

      <div class="flex space-x-4">
        <button
          class="flex-1 px-4 py-3 bg-white/10 rounded-xl text-white hover:bg-white/20 transition-colors"
          on:click={() => showDeleteAllModal.set(false)}
        >
          <i class="fas fa-times mr-2"></i>
          {$Locales.cancel}
        </button>
        <button
          class="flex-1 px-4 py-3 bg-red-500/20 border border-red-500/30 rounded-xl text-red-400 hover:bg-red-500/30 transition-colors"
          on:click={deleteAllTransactions}
        >
          <i class="fas fa-trash mr-2"></i>
          {$Locales.delete_all}
        </button>
      </div>
    </div>
  </div>
{/if}
