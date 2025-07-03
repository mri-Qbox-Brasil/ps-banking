<script lang="ts">
  import { writable } from "svelte/store";
  import { onMount } from "svelte";
  import { fetchNui } from "../utils/fetchNui";
  import { slide, fade, scale } from "svelte/transition";
  import { quintOut } from "svelte/easing";
  import { Bills } from "../store/data";
  import { Notify, Locales, Currency } from "../store/data";

  let transactions = Bills;
  let searchQuery = writable("");

  $: filteredTransactions = $transactions.filter(
    (transaction) =>
      transaction.description
        .toLowerCase()
        .includes($searchQuery.toLowerCase()) ||
      transaction.type.toLowerCase().includes($searchQuery.toLowerCase())
  );

  function formatDate(dateString: string) {
    const options: Intl.DateTimeFormatOptions = {
      year: "numeric",
      month: "numeric",
      day: "numeric",
    };
    return new Date(dateString).toLocaleDateString(undefined, options);
  }

  async function payBill(transaction: { id: any; type: any }) {
    try {
      const result = await fetchNui("ps-banking:client:payBill", {
        id: transaction.id,
      });
      if (result) {
        Notify(
          `${$Locales.pay_invoice} #${transaction.id} ${$Locales.from} ${transaction.type}`,
          $Locales.payment_completed,
          "coins"
        );
        transactions.update((items) => {
          const index = items.findIndex((t) => transaction.id === t.id);
          if (index !== -1) {
            items.splice(index, 1);
          }
          return items;
        });
        return true;
      } else {
        Notify(`${$Locales.no_money_on_account}`, `${$Locales.error}`, "coins");
        return false;
      }
    } catch (error) {
      console.error(error);
      return false;
    }
  }

  onMount(async () => {
    try {
      const response = await fetchNui("ps-banking:client:getBills", {});
      Bills.set(response);
    } catch (error) {
      console.error(error);
    }
  });
</script>

<div class="h-full flex flex-col p-8 overflow-y-auto">
  <!-- Page Header -->
  <div class="flex items-center justify-between mb-8">
    <div>
      <h1 class="text-3xl font-bold text-white mb-2">{$Locales.bills}</h1>
      <p class="text-white/60">{$Locales.manage_pending_bills_payments}</p>
    </div>
    <div class="flex items-center space-x-4">
      <div class="modern-card px-4 py-2">
        <div class="flex items-center space-x-2">
          <i class="fas fa-file-invoice text-yellow-400"></i>
          <span class="text-sm text-white/80">{$transactions.length} {$Locales.bills_count}</span>
        </div>
      </div>
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

  <!-- Bills Grid -->
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
              <div class="w-12 h-12 bg-orange-500/20 rounded-xl flex items-center justify-center">
                <i class="fas fa-file-invoice text-orange-400 text-lg"></i>
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

            <div class="flex items-center space-x-4">
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
              </div>

              {#if !transaction.isPaid}
                <button
                  class="action-button flex items-center space-x-2"
                  on:click={() => payBill(transaction)}
                >
                  <i class="fas fa-credit-card"></i>
                  <span>{$Locales.pay_invoice}</span>
                </button>
              {:else}
                <div class="px-4 py-2 bg-green-500/20 rounded-lg border border-green-500/30">
                  <span class="text-green-400 text-sm font-medium">{$Locales.paid}</span>
                </div>
              {/if}
            </div>
          </div>
        </div>
      {/each}
    {:else}
      <div class="modern-card p-12 text-center">
        <i class="fas fa-file-invoice text-white/30 text-5xl mb-4"></i>
        <h3 class="text-xl font-semibold text-white mb-2">{$Locales.no_bills_found}</h3>
        <p class="text-white/60">
          {$searchQuery ? $Locales.no_bills_match_search : $Locales.no_pending_bills_moment}
        </p>
      </div>
    {/if}
  </div>
</div>
