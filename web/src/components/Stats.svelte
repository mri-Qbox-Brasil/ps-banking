<script lang="ts">
  import { onMount } from "svelte";
  import { writable } from "svelte/store";
  import { slide } from "svelte/transition";
  import { quintOut } from "svelte/easing";
  import { fetchNui } from "../utils/fetchNui";
  import { Locales, Currency, bankBalance, currentCash } from "../store/data";

  let weeklyStats = writable({ totalReceived: 0, totalUsed: 0, totalTransactions: 0 });
  let monthlyStats = writable({ totalReceived: 0, totalUsed: 0, totalTransactions: 0 });
  let allTimeStats = writable({ totalReceived: 0, totalUsed: 0, totalTransactions: 0 });

  async function fetchStats() {
    try {
      const weekly = await fetchNui("ps-banking:client:getWeeklySummary", {});
      const monthly = await fetchNui("ps-banking:client:getMonthlySummary", {});
      const allTime = await fetchNui("ps-banking:client:getAllTimeSummary", {});
      
      weeklyStats.set(weekly || { totalReceived: 0, totalUsed: 0, totalTransactions: 0 });
      monthlyStats.set(monthly || { totalReceived: 0, totalUsed: 0, totalTransactions: 0 });
      allTimeStats.set(allTime || { totalReceived: 0, totalUsed: 0, totalTransactions: 0 });
    } catch (error) {
      console.error(error);
    }
  }

  onMount(() => {
    fetchStats();
  });
</script>

<div class="h-full flex flex-col p-8 overflow-y-auto">
  <!-- Page Header -->
  <div class="flex items-center justify-between mb-8">
    <div>
      <h1 class="text-3xl font-bold text-white mb-2">{$Locales.stats}</h1>
      <p class="text-white/60">{$Locales.financial_statistics_analytics}</p>
    </div>
    <div class="flex items-center space-x-4">
      <div class="modern-card px-4 py-2">
        <div class="flex items-center space-x-2">
                      <i class="fas fa-chart-line text-green-400"></i>
          <span class="text-sm text-white/80">{$Locales.analytics}</span>
        </div>
      </div>
    </div>
  </div>

  <!-- Current Balance Overview -->
  <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
    <div class="modern-card p-6">
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

    <div class="modern-card p-6">
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

  <!-- Statistics Cards -->
  <div class="grid gap-8">
    <!-- Weekly Stats -->
    <div class="modern-card p-6">
      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center space-x-3">
          <div class="w-10 h-10 bg-green-500/20 rounded-lg flex items-center justify-center">
            <i class="fas fa-calendar-week text-green-400"></i>
          </div>
          <h3 class="text-xl font-semibold text-white">{$Locales.weekly_summary}</h3>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div class="bg-white/5 rounded-xl p-4">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-white/60 text-sm">{$Locales.income}</p>
              <p class="text-lg font-bold text-green-400">
                {#if $weeklyStats.totalReceived >= 1000000}
                  R$ {($weeklyStats.totalReceived / 1000000).toFixed(1)}M
                {:else if $weeklyStats.totalReceived >= 1000}
                  R$ {($weeklyStats.totalReceived / 1000).toFixed(1)}K
                {:else}
                  R$ {$weeklyStats.totalReceived.toLocaleString()}
                {/if}
              </p>
            </div>
            <i class="fas fa-arrow-up text-green-400"></i>
          </div>
        </div>

        <div class="bg-white/5 rounded-xl p-4">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-white/60 text-sm">{$Locales.expenses}</p>
              <p class="text-lg font-bold text-red-400">
                {#if $weeklyStats.totalUsed >= 1000000}
                  R$ {($weeklyStats.totalUsed / 1000000).toFixed(1)}M
                {:else if $weeklyStats.totalUsed >= 1000}
                  R$ {($weeklyStats.totalUsed / 1000).toFixed(1)}K
                {:else}
                  R$ {$weeklyStats.totalUsed.toLocaleString()}
                {/if}
              </p>
            </div>
            <i class="fas fa-arrow-down text-red-400"></i>
          </div>
        </div>

        <div class="bg-white/5 rounded-xl p-4">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-white/60 text-sm">{$Locales.net_change}</p>
              <p class={`text-lg font-bold ${($weeklyStats.totalReceived - $weeklyStats.totalUsed) >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                {#if Math.abs($weeklyStats.totalReceived - $weeklyStats.totalUsed) >= 1000000}
                  R$ {(Math.abs($weeklyStats.totalReceived - $weeklyStats.totalUsed) / 1000000).toFixed(1)}M
                {:else if Math.abs($weeklyStats.totalReceived - $weeklyStats.totalUsed) >= 1000}
                  R$ {(Math.abs($weeklyStats.totalReceived - $weeklyStats.totalUsed) / 1000).toFixed(1)}K
                {:else}
                  R$ {Math.abs($weeklyStats.totalReceived - $weeklyStats.totalUsed).toLocaleString()}
                {/if}
              </p>
            </div>
            <i class={`fas ${($weeklyStats.totalReceived - $weeklyStats.totalUsed) >= 0 ? 'fa-chart-line text-green-400' : 'fa-chart-line-down text-red-400'}`}></i>
          </div>
        </div>
      </div>
    </div>

    <!-- Monthly Stats -->
    <div class="modern-card p-6">
      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center space-x-3">
          <div class="w-10 h-10 bg-blue-500/20 rounded-lg flex items-center justify-center">
            <i class="fas fa-calendar-alt text-blue-400"></i>
          </div>
          <h3 class="text-xl font-semibold text-white">{$Locales.monthly_summary}</h3>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div class="bg-white/5 rounded-xl p-4">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-white/60 text-sm">{$Locales.income}</p>
              <p class="text-lg font-bold text-green-400">
                {#if $monthlyStats.totalReceived >= 1000000}
                  R$ {($monthlyStats.totalReceived / 1000000).toFixed(1)}M
                {:else if $monthlyStats.totalReceived >= 1000}
                  R$ {($monthlyStats.totalReceived / 1000).toFixed(1)}K
                {:else}
                  R$ {$monthlyStats.totalReceived.toLocaleString()}
                {/if}
              </p>
            </div>
            <i class="fas fa-arrow-up text-green-400"></i>
          </div>
        </div>

        <div class="bg-white/5 rounded-xl p-4">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-white/60 text-sm">{$Locales.expenses}</p>
              <p class="text-lg font-bold text-red-400">
                {#if $monthlyStats.totalUsed >= 1000000}
                  ${($monthlyStats.totalUsed / 1000000).toFixed(1)}M
                {:else if $monthlyStats.totalUsed >= 1000}
                  ${($monthlyStats.totalUsed / 1000).toFixed(1)}K
                {:else}
                  ${$monthlyStats.totalUsed.toLocaleString()}
                {/if}
              </p>
            </div>
            <i class="fas fa-arrow-down text-red-400"></i>
          </div>
        </div>

        <div class="bg-white/5 rounded-xl p-4">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-white/60 text-sm">{$Locales.net_change}</p>
              <p class={`text-lg font-bold ${($monthlyStats.totalReceived - $monthlyStats.totalUsed) >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                {#if Math.abs($monthlyStats.totalReceived - $monthlyStats.totalUsed) >= 1000000}
                  ${(Math.abs($monthlyStats.totalReceived - $monthlyStats.totalUsed) / 1000000).toFixed(1)}M
                {:else if Math.abs($monthlyStats.totalReceived - $monthlyStats.totalUsed) >= 1000}
                  ${(Math.abs($monthlyStats.totalReceived - $monthlyStats.totalUsed) / 1000).toFixed(1)}K
                {:else}
                  ${Math.abs($monthlyStats.totalReceived - $monthlyStats.totalUsed).toLocaleString()}
                {/if}
              </p>
            </div>
            <i class={`fas ${($monthlyStats.totalReceived - $monthlyStats.totalUsed) >= 0 ? 'fa-chart-line text-green-400' : 'fa-chart-line-down text-red-400'}`}></i>
          </div>
        </div>
      </div>
    </div>

    <!-- All Time Stats -->
    <div class="modern-card p-6">
      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center space-x-3">
          <div class="w-10 h-10 bg-yellow-500/20 rounded-lg flex items-center justify-center">
            <i class="fas fa-infinity text-yellow-400"></i>
          </div>
          <h3 class="text-xl font-semibold text-white">{$Locales.all_time_summary}</h3>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div class="bg-white/5 rounded-xl p-4">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-white/60 text-sm">{$Locales.total_income}</p>
              <p class="text-lg font-bold text-green-400">
                {#if $allTimeStats.totalReceived >= 1000000}
                  ${($allTimeStats.totalReceived / 1000000).toFixed(1)}M
                {:else if $allTimeStats.totalReceived >= 1000}
                  ${($allTimeStats.totalReceived / 1000).toFixed(1)}K
                {:else}
                  ${$allTimeStats.totalReceived.toLocaleString()}
                {/if}
              </p>
            </div>
            <i class="fas fa-arrow-up text-green-400"></i>
          </div>
        </div>

        <div class="bg-white/5 rounded-xl p-4">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-white/60 text-sm">{$Locales.total_expenses}</p>
              <p class="text-lg font-bold text-red-400">
                {#if $allTimeStats.totalUsed >= 1000000}
                  ${($allTimeStats.totalUsed / 1000000).toFixed(1)}M
                {:else if $allTimeStats.totalUsed >= 1000}
                  ${($allTimeStats.totalUsed / 1000).toFixed(1)}K
                {:else}
                  ${$allTimeStats.totalUsed.toLocaleString()}
                {/if}
              </p>
            </div>
            <i class="fas fa-arrow-down text-red-400"></i>
          </div>
        </div>

        <div class="bg-white/5 rounded-xl p-4">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-white/60 text-sm">{$Locales.net_lifetime}</p>
              <p class={`text-lg font-bold ${($allTimeStats.totalReceived - $allTimeStats.totalUsed) >= 0 ? 'text-green-400' : 'text-red-400'}`}>
                {#if Math.abs($allTimeStats.totalReceived - $allTimeStats.totalUsed) >= 1000000}
                  ${(Math.abs($allTimeStats.totalReceived - $allTimeStats.totalUsed) / 1000000).toFixed(1)}M
                {:else if Math.abs($allTimeStats.totalReceived - $allTimeStats.totalUsed) >= 1000}
                  ${(Math.abs($allTimeStats.totalReceived - $allTimeStats.totalUsed) / 1000).toFixed(1)}K
                {:else}
                  ${Math.abs($allTimeStats.totalReceived - $allTimeStats.totalUsed).toLocaleString()}
                {/if}
              </p>
            </div>
            <i class={`fas ${($allTimeStats.totalReceived - $allTimeStats.totalUsed) >= 0 ? 'fa-trophy text-yellow-400' : 'fa-chart-line-down text-red-400'}`}></i>
          </div>
        </div>
      </div>
    </div>
  </div>
</div>
