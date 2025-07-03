<script lang="ts">
  import { onMount } from "svelte";
  import { useNuiEvent } from "../utils/useNuiEvent";
  import { fetchNui } from "../utils/fetchNui";
  import { visibility } from "../store/stores";
  import OverviewPage from "./Overview.svelte";
  import BillsPage from "./Bills.svelte";
  import HistoryPage from "./History.svelte";
  import HeavPage from "./Heav.svelte";
  import IndseatPage from "./Indseat.svelte";
  import StatsPage from "./Stats.svelte";
  import AccountsPage from "./Accounts.svelte";
  import { slide, fade, scale } from "svelte/transition";
  import { quintOut, cubicOut } from "svelte/easing";
  import {
    showOverview,
    showBills,
    showHistory,
    showHeav,
    showIndseat,
    showStats,
    showAccounts,
    Locales,
    bankBalance,
    currentCash,
    activeView
  } from "../store/data";

  let currentActiveView;
  activeView.subscribe(value => {
    currentActiveView = value;
  });

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

  onMount(async () => {
    updateBalances();
    try {
      const response = await fetchNui("ps-banking:client:getLocales", {});
      Locales.set(response);
    } catch (error) {
      console.error(error);
    }
  });

  const navigationItems = [
    { key: 'overview', icon: 'house', label: 'overview' },
    { key: 'bills', icon: 'file-invoice', label: 'bills' },
    { key: 'history', icon: 'clock-rotate-left', label: 'history' },
    { key: 'withdraw', icon: 'arrow-down', label: 'withdraw' },
    { key: 'deposit', icon: 'arrow-up', label: 'deposit' },
    { key: 'accounts', icon: 'piggy-bank', label: 'accounts' }
  ];

  function setActiveView(view) {
    // Reset all views first
    showOverview.set(false);
    showBills.set(false);
    showHistory.set(false);
    showHeav.set(false);
    showIndseat.set(false);
    showStats.set(false);
    showAccounts.set(false);

    // Then set the active view
    activeView.set(view);

    // Finally, set the corresponding view to true
    switch (view) {
      case 'overview':
        showOverview.set(true);
        break;
      case 'bills':
        showBills.set(true);
        break;
      case 'history':
        showHistory.set(true);
        break;
      case 'withdraw':
        showHeav.set(true);
        break;
      case 'deposit':
        showIndseat.set(true);
        break;
      case 'accounts':
        showAccounts.set(true);
        break;
    }
  }

</script>

<div class="fixed inset-0 flex items-center justify-center p-4 z-10">
  <div
    class="w-full max-w-7xl h-full max-h-[900px] modern-card overflow-hidden"
    in:scale={{ duration: 600, easing: cubicOut }}
    out:fade={{ duration: 400 }}
  >
    <div class="flex h-full">
      <!-- Modern Sidebar -->
      <div class="w-72 flex flex-col bg-black/20 border-r border-white/10">
        <!-- Header -->
        <div class="p-6 border-b border-white/10">
          <div class="flex items-center space-x-3">
            <div class="w-12 h-12 bg-gradient-to-r from-emerald-500 to-green-500 rounded-xl flex items-center justify-center">
              <i class="fas fa-piggy-bank text-white text-xl"></i>
            </div>
            <div>
              <h1 class="text-xl font-bold text-white">Banco</h1>
              <p class="text-sm text-white/60">Painel Financeiro</p>
            </div>
          </div>
        </div>

        <!-- Balance Card -->
        <div class="p-6">
          <div class="stat-card">
            <div class="flex items-center justify-between mb-4">
              <div class="flex items-center space-x-3">
                <div class="w-10 h-10 bg-green-500/20 rounded-lg flex items-center justify-center">
                  <i class="fas fa-wallet text-green-400 text-lg"></i>
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-sm text-white/60">Saldo Total</p>
                  <p class="text-xl font-bold text-white truncate" title="{$bankBalance.toLocaleString('pt-BR', {
                    style: 'currency',
                    currency: 'BRL',
                    minimumFractionDigits: 0,
                  })}">
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
            <div class="text-xs text-white/50">
              Dinheiro: {#if $currentCash >= 1000000}
                R$ {($currentCash / 1000000).toFixed(1)}M
              {:else if $currentCash >= 1000}
                R$ {($currentCash / 1000).toFixed(1)}K
              {:else}
                R$ {$currentCash.toLocaleString()}
              {/if}
            </div>
          </div>
        </div>

        <!-- Navigation -->
        <div class="flex-1 px-4 pb-4">
          <div class="space-y-2">
            {#each navigationItems as item}
              <button
                class="nav-item w-full p-4 flex items-center space-x-3 text-left {$activeView === item.key ? 'active' : ''}"
                on:click={() => setActiveView(item.key)}
              >
                <div class="w-10 h-10 {$activeView === item.key ? 'bg-white/10' : 'bg-white/5'} rounded-lg flex items-center justify-center">
                  <i class="fas fa-{item.icon} {$activeView === item.key ? 'text-white' : 'text-white/70'} text-lg"></i>
                </div>
                <div class="flex-1">
                  <p class="font-medium capitalize {$activeView === item.key ? 'text-white' : 'text-white/80'}">{$Locales[item.label] || item.label}</p>
                </div>
                {#if $activeView === item.key}
                  <div class="w-2 h-2 bg-indigo-400 rounded-full"></div>
                {/if}
              </button>
            {/each}
          </div>
        </div>

        <!-- Close Button -->
        <div class="p-4 border-t border-white/10">
          <button
            class="w-full p-3 rounded-xl bg-red-500/10 border border-red-500/30 hover:bg-red-500/20 transition-colors flex items-center justify-center space-x-3"
            on:click={() => {
              fetchNui("ps-banking:client:hideUI");
              visibility.set(false);
            }}
          >
            <i class="fas fa-times text-red-400 text-lg"></i>
            <span class="text-red-400 font-medium">{$Locales.close || 'Fechar'}</span>
          </button>
        </div>
      </div>

      <!-- Main Content Area -->
      <div class="flex-1 flex flex-col">
        <div class="flex-1 overflow-hidden">
          {#if $showOverview}
            <div in:fade={{ duration: 150 }} out:fade={{ duration: 75 }}>
              <OverviewPage />
            </div>
          {:else if $showBills}
            <div in:fade={{ duration: 150 }} out:fade={{ duration: 75 }}>
              <BillsPage />
            </div>
          {:else if $showHistory}
            <div in:fade={{ duration: 150 }} out:fade={{ duration: 75 }}>
              <HistoryPage />
            </div>
          {:else if $showHeav}
            <div in:fade={{ duration: 150 }} out:fade={{ duration: 75 }}>
              <HeavPage />
            </div>
          {:else if $showIndseat}
            <div in:fade={{ duration: 150 }} out:fade={{ duration: 75 }}>
              <IndseatPage />
            </div>
          {:else if $showStats}
            <div in:fade={{ duration: 150 }} out:fade={{ duration: 75 }}>
              <StatsPage />
            </div>
          {:else if $showAccounts}
            <div in:fade={{ duration: 150 }} out:fade={{ duration: 75 }}>
              <AccountsPage />
            </div>
          {/if}
        </div>
      </div>
    </div>
  </div>
</div>
