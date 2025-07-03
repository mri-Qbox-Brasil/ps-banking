<script lang="ts">
  import { writable } from "svelte/store";
  import { onMount } from "svelte";
  import Chart from "chart.js/auto";
  import { fetchNui } from "../utils/fetchNui";
  import { quintOut } from "svelte/easing";
  import { slide, fade, scale } from "svelte/transition";
  import {
    showOverview,
    showBills,
    showHistory,
    showHeav,
    notifications,
    Bills,
    Notify,
    Transactions,
    currentCash,
    bankBalance,
    Locales,
    Currency,
    type Notification,
  } from "../store/data";

  let notificationId = 0;
  let transactions = Bills;
  let phone = false;
  let showSureModalBills = writable(false);
  let showTransferModal = writable(false);
  let transferData = writable({
    idOrPhone: "",
    amount: 0,
    confirm: false,
    contactType: "none",
  });

  let weeklyData = writable({
    totalReceived: 0,
    totalUsed: 0,
  });

  let chart: Chart;
  let chartCanvas: HTMLCanvasElement;

  async function fetchWeeklySummary() {
    try {
      const response = await fetchNui("ps-banking:client:getWeeklySummary", {});
      if (response) {
        weeklyData.set(response);
      }
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

  async function payAllBills() {
    const success = await fetchNui("ps-banking:client:payAllBills", {});
    if (success) {
      await getBills();
      Notify(
        $Locales.pay_all_bills_success,
        $Locales.payment_completed,
        "money-bill"
      );
    } else {
      Notify(
        $Locales.pay_all_bills_error,
        $Locales.error,
        "circle-exclamation"
      );
    }
  }

  function openModal() {
    showTransferModal.set(true);
  }

  function closeModal() {
    showTransferModal.set(false);
    transferData.set({
      idOrPhone: "",
      amount: 0,
      confirm: false,
      contactType: "none",
    });
  }

  async function getBills() {
    try {
      const response = await fetchNui("ps-banking:client:getBills", {});
      Bills.set(response);
    } catch (error) {
      console.error(error);
    }
  }

  async function getHistory() {
    try {
      const history = await fetchNui("ps-banking:client:getHistory", {});
      Transactions.set(history);
    } catch (error) {
      console.error(error);
    }
  }

  async function confirmTransfer(id: any, amount: any, method: any) {
    try {
      const response = await fetchNui("ps-banking:client:transferMoney", {
        id: id,
        amount: amount,
        method: method,
      });
      if (response.success) {
        Notify(response.message, $Locales.payment_completed, "user");
      } else {
        Notify(response.message, $Locales.error, "user");
      }
    } catch (error) {
      console.error(error);
    }
    transferData.update((data) => {
      data.confirm = true;
      return data;
    });
    showTransferModal.set(false);
    transferData.set({
      idOrPhone: "",
      amount: 0,
      confirm: false,
      contactType: "none",
    });
  }

  let bankData = {
    balance: $bankBalance,
    cash: $currentCash,
    transactions: $Transactions,
  };

  $: bankData = {
    balance: $bankBalance,
    cash: $currentCash,
    transactions: $Transactions,
  };

  async function heav() {
    try {
      const response = await fetchNui("ps-banking:client:ATMwithdraw", {
        amount: $bankBalance,
      });
      if (response) {
        updateStuff();
      }
    } catch (error) {
      console.error(error);
    }
  }

  async function deposit() {
    try {
      const response = await fetchNui("ps-banking:client:ATMdeposit", {
        amount: $currentCash,
      });
      if (response) {
        updateStuff();
      }
    } catch (error) {
      console.error(error);
    }
  }

  function createChart() {
    if (chartCanvas) {
      chart = new Chart(chartCanvas, {
        type: "bar",
        data: {
          labels: [$Locales.income, $Locales.expenses],
          datasets: [
            {
              label: $Locales.weekly_summary,
              data: [0, 0],
              backgroundColor: ["#3b82f6", "#ef4444"],
            },
          ],
        },
        options: {
          responsive: true,
          scales: {
            y: {
              beginAtZero: true,
            },
          },
        },
      });
    }
  }

  $: {
    weeklyData.subscribe((data) => {
      if (chart) {
        chart.data.datasets[0].data = [data.totalReceived, data.totalUsed];
        chart.update();
      }
    });
  }

  async function updateStuff() {
    // Hot update
    await getBills();
    await getHistory();
    await fetchWeeklySummary();
    await updateBalances();
  }
  
  async function phoneOption() {
    try {
      const response = await fetchNui("ps-banking:client:phoneOption", {});
      phone = response
    } catch (error) {
      console.error(error);
    }
  }

  onMount(async () => {
    createChart();
    updateStuff();
    updateStuff();
    phoneOption();
  });
</script>

<div class="h-full flex flex-col p-8 overflow-y-auto">
  <!-- Page Header -->
  <div class="flex items-center justify-between mb-8">
    <div>
      <h1 class="text-3xl font-bold text-white mb-2">{$Locales.overview}</h1>
      <p class="text-white/60">{$Locales.financial_summary_quick_actions}</p>
    </div>
    <div class="flex items-center space-x-4">
      <div class="modern-card px-4 py-2">
        <div class="flex items-center space-x-2">
          <div class="w-2 h-2 bg-green-400 rounded-full animate-pulse"></div>
          <span class="text-sm text-white/80">{$Locales.live}</span>
        </div>
      </div>
    </div>
  </div>

  <!-- Quick Actions Grid -->
  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
    <!-- Transfer Money -->
    <div class="modern-card modern-card-hover p-6 group cursor-pointer" on:click={openModal}>
      <div class="flex items-center justify-between mb-4">
        <div class="w-12 h-12 bg-blue-500/20 rounded-xl flex items-center justify-center group-hover:bg-blue-500/30 transition-colors">
          <i class="fas fa-exchange-alt text-blue-400 text-xl"></i>
        </div>
        <i class="fas fa-arrow-right text-white/30 group-hover:text-white/60 transition-colors"></i>
      </div>
      <h3 class="text-lg font-semibold text-white mb-2">{$Locales.transfer_money}</h3>
      <p class="text-sm text-white/60">{$Locales.easy_transfer}</p>
    </div>

    <!-- Pay Bills -->
    <div class="modern-card modern-card-hover p-6 group cursor-pointer" on:click={() => showSureModalBills.set(true)}>
      <div class="flex items-center justify-between mb-4">
        <div class="w-12 h-12 bg-orange-500/20 rounded-xl flex items-center justify-center group-hover:bg-orange-500/30 transition-colors">
          <i class="fas fa-file-invoice-dollar text-orange-400 text-xl"></i>
        </div>
        <i class="fas fa-arrow-right text-white/30 group-hover:text-white/60 transition-colors"></i>
      </div>
      <h3 class="text-lg font-semibold text-white mb-2">{$Locales.pay_bills}</h3>
      <p class="text-sm text-white/60">{$Locales.pay_pending_bills}</p>
    </div>

    <!-- Withdraw -->
    <div class="modern-card modern-card-hover p-6 group cursor-pointer" on:click={() => {
      if ($bankBalance <= 0) {
        Notify($Locales.no_money_on_account, $Locales.error, "credit-card");
      } else {
        Notify($Locales.withdraw_all_success, $Locales.success, "credit-card");
        setTimeout(() => { heav(); }, 200);
      }
    }}>
      <div class="flex items-center justify-between mb-4">
        <div class="w-12 h-12 bg-red-500/20 rounded-xl flex items-center justify-center group-hover:bg-red-500/30 transition-colors">
          <i class="fas fa-arrow-down text-red-400 text-xl"></i>
        </div>
        <i class="fas fa-arrow-right text-white/30 group-hover:text-white/60 transition-colors"></i>
      </div>
      <h3 class="text-lg font-semibold text-white mb-2">{$Locales.withdraw_all_money}</h3>
      <p class="text-sm text-white/60">{$Locales.withdraw_all_from_account}</p>
    </div>

    <!-- Deposit -->
    <div class="modern-card modern-card-hover p-6 group cursor-pointer" on:click={() => {
      if ($currentCash <= 0) {
        Notify($Locales.no_cash_on_you, $Locales.error, "coins");
      } else {
        Notify($Locales.deposit_all_success, $Locales.success, "coins");
        setTimeout(() => { deposit(); }, 200);
      }
    }}>
      <div class="flex items-center justify-between mb-4">
        <div class="w-12 h-12 bg-green-500/20 rounded-xl flex items-center justify-center group-hover:bg-green-500/30 transition-colors">
          <i class="fas fa-arrow-up text-green-400 text-xl"></i>
        </div>
        <i class="fas fa-arrow-right text-white/30 group-hover:text-white/60 transition-colors"></i>
      </div>
      <h3 class="text-lg font-semibold text-white mb-2">{$Locales.deposit_cash}</h3>
      <p class="text-sm text-white/60">{$Locales.deposit_all_cash}</p>
    </div>
  </div>

  <!-- Statistics and Information Grid -->
  <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
    <!-- Weekly Summary -->
    <div class="modern-card p-6">
      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center space-x-3">
          <div class="w-10 h-10 bg-green-500/20 rounded-lg flex items-center justify-center">
            <i class="fas fa-calendar-week text-green-400"></i>
          </div>
          <h3 class="text-xl font-semibold text-white">{$Locales.weekly_summary}</h3>
        </div>
      </div>

      <div class="space-y-4">
        <div class="flex items-center justify-between p-4 bg-white/5 rounded-xl">
          <div class="flex items-center space-x-3">
            <div class="w-8 h-8 bg-green-500/20 rounded-lg flex items-center justify-center">
              <i class="fas fa-arrow-up text-green-400 text-sm"></i>
            </div>
            <span class="text-white/80">{$Locales.income}</span>
          </div>
          <span class="text-green-400 font-semibold">
            {#if $weeklyData.totalReceived !== undefined}
              {$weeklyData.totalReceived.toLocaleString($Currency.lang, {
                style: "currency",
                currency: $Currency.currency,
                minimumFractionDigits: 0,
              })}
            {:else}
              $0
            {/if}
          </span>
        </div>

        <div class="flex items-center justify-between p-4 bg-white/5 rounded-xl">
          <div class="flex items-center space-x-3">
            <div class="w-8 h-8 bg-red-500/20 rounded-lg flex items-center justify-center">
              <i class="fas fa-arrow-down text-red-400 text-sm"></i>
            </div>
            <span class="text-white/80">{$Locales.expenses}</span>
          </div>
          <span class="text-red-400 font-semibold">
            {#if $weeklyData.totalUsed !== undefined}
              {$weeklyData.totalUsed.toLocaleString($Currency.lang, {
                style: "currency",
                currency: $Currency.currency,
                minimumFractionDigits: 0,
              })}
            {:else}
              $0
            {/if}
          </span>
        </div>

        <div class="mt-6 bg-white/5 rounded-xl p-4">
          <div class="flex items-center mb-3">
            <i class="fas fa-chart-bar text-white/60 mr-2"></i>
            <span class="text-white/80 text-sm">{$Locales.report}</span>
          </div>
          <canvas bind:this={chartCanvas} class="w-full h-32"></canvas>
        </div>
      </div>
    </div>

    <!-- Recent Transactions -->
    <div class="modern-card p-6">
      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center space-x-3">
          <div class="w-10 h-10 bg-blue-500/20 rounded-lg flex items-center justify-center">
            <i class="fas fa-history text-blue-400"></i>
          </div>
          <h3 class="text-xl font-semibold text-white">{$Locales.latest_transactions}</h3>
        </div>
        <div class="bg-white/10 rounded-full px-3 py-1">
          <span class="text-white/80 text-sm">{bankData.transactions.length}</span>
        </div>
      </div>

      <div class="space-y-3 max-h-80 overflow-y-auto">
        {#if bankData.transactions.length > 0}
          {#each bankData.transactions.slice(0, 6) as transaction}
            <div class="flex items-center justify-between p-3 bg-white/5 rounded-xl hover:bg-white/10 transition-colors">
              <div class="flex-1">
                <p class="text-white/90 text-sm font-medium truncate">{transaction.description}</p>
                <p class="text-white/50 text-xs">{$Locales.transaction}</p>
              </div>
              <div class="text-right">
                <span class={`font-semibold ${transaction.isIncome ? "text-green-400" : "text-red-400"}`}>
                  {transaction.isIncome ? "+" : "-"}
                  {transaction.amount.toLocaleString($Currency.lang, {
                    style: "currency",
                    currency: $Currency.currency,
                    minimumFractionDigits: 0,
                  })}
                </span>
              </div>
            </div>
          {/each}

          <div class="pt-4">
            <button
              class="action-button w-full"
              on:click={() => {
                showOverview.set(false);
                showHistory.set(true);
              }}
            >
              {$Locales.see_all}
            </button>
          </div>
        {:else}
          <div class="text-center py-8">
            <i class="fas fa-receipt text-white/30 text-3xl mb-3"></i>
            <p class="text-white/60">{$Locales.no_transactions}</p>
          </div>
        {/if}
      </div>
    </div>

    <!-- Unpaid Bills -->
    <div class="modern-card p-6">
      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center space-x-3">
          <div class="w-10 h-10 bg-yellow-500/20 rounded-lg flex items-center justify-center">
            <i class="fas fa-exclamation-triangle text-yellow-400"></i>
          </div>
          <h3 class="text-xl font-semibold text-white">{$Locales.unpaid_bills}</h3>
        </div>
        <div class="bg-white/10 rounded-full px-3 py-1">
          <span class="text-white/80 text-sm">{$transactions.length}</span>
        </div>
      </div>

      <div class="space-y-3 max-h-80 overflow-y-auto">
        {#if $transactions.length > 0}
          {#each $transactions.slice(0, 4) as transaction (transaction.id)}
            {#if !transaction.isPaid}
              <div class="p-4 bg-white/5 rounded-xl hover:bg-white/10 transition-colors">
                <div class="flex justify-between items-start mb-2">
                  <div class="flex-1">
                    <p class="text-white/90 font-medium text-sm">{transaction.description}</p>
                    <p class="text-white/50 text-xs">#{transaction.id}</p>
                  </div>
                  <span class={`font-semibold text-sm ${transaction.isIncome ? "text-green-400" : "text-red-400"}`}>
                    {transaction.isIncome ? "+" : "-"}
                    {transaction.amount.toLocaleString($Currency.lang, {
                      style: "currency",
                      currency: $Currency.currency,
                      minimumFractionDigits: 0,
                    })}
                  </span>
                </div>
                <div class="flex items-center justify-between">
                  <span class="text-white/50 text-xs">{transaction.timeAgo}</span>
                  <span class="text-white/50 text-xs">{transaction.date}</span>
                </div>
              </div>
            {/if}
          {/each}

          <div class="pt-4">
            <button
              class="action-button w-full"
              on:click={() => {
                showOverview.set(false);
                showBills.set(true);
              }}
            >
              {$Locales.see_all}
            </button>
          </div>
        {:else}
          <div class="text-center py-8">
            <i class="fas fa-check-circle text-green-400 text-3xl mb-3"></i>
            <p class="text-white/60">{$Locales.no_unpaid_bills}</p>
          </div>
        {/if}
      </div>
    </div>
  </div>
</div>

<!-- Transfer Modal -->
{#if $showTransferModal}
  <div class="modal-backdrop fixed inset-0 flex items-center justify-center z-50">
    <div
      class="modern-card p-8 w-full max-w-md mx-4"
      in:scale={{ duration: 300, easing: quintOut }}
      out:scale={{ duration: 250, easing: quintOut }}
    >
      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center space-x-3">
          <div class="w-12 h-12 bg-blue-500/20 rounded-xl flex items-center justify-center">
            <i class="fas fa-exchange-alt text-blue-400 text-xl"></i>
          </div>
          <h2 class="text-2xl font-bold text-white">{$Locales.transfer_money}</h2>
        </div>
        <button
          class="w-8 h-8 bg-white/10 rounded-lg flex items-center justify-center hover:bg-white/20 transition-colors"
          on:click={closeModal}
        >
          <i class="fas fa-times text-white/60"></i>
        </button>
      </div>

      <!-- Payment Method Selection -->
      <div class="mb-6">
        <label class="block text-white/80 font-medium mb-3">{$Locales.payment_method}</label>
        <div class="space-y-3">
          {#if phone}
            <label class="flex items-center p-4 bg-white/5 rounded-xl cursor-pointer border border-white/10 hover:border-white/20 transition-colors">
              <input
                type="radio"
                name="payment"
                value="phone"
                bind:group={$transferData.contactType}
                class="hidden peer"
              />
              <i class="fa-duotone fa-phone text-lg text-blue-400 mr-3"></i>
              <span class="text-white font-bold">{$Locales.phone_number}</span
              >
              <div class="ml-auto hidden peer-checked:block">
                <i class="fa-duotone fa-check-circle text-blue-400"></i>
              </div>
            </label>
          {/if}
          <label
            class="flex items-center cursor-pointer bg-gray-700/50 rounded-lg p-3 border border-gray-600/20 hover:border-blue-400 transition duration-300"
          >
            <input
              type="radio"
              name="payment"
              value="id"
              bind:group={$transferData.contactType}
              class="hidden peer"
            />
            <i class="fa-duotone fa-id-badge text-lg text-blue-400 mr-3"></i>
            <span class="text-white font-bold">{$Locales.id}</span>
            <div class="ml-auto hidden peer-checked:block">
              <i class="fa-duotone fa-check-circle text-blue-400"></i>
            </div>
          </label>
        </div>
      </div>

      <!-- ID or Phone Number Input -->
      {#if $transferData.contactType === "phone" || $transferData.contactType === "id"}
        <div class="mb-6">
          <label class="block text-gray-400 mb-2">
            <i class="fa-duotone fa-id-card text-blue-400 mr-2"></i>
            {#if phone}
              {$Locales.id_or_phone_number}
            {:else}
              {$Locales.id}
            {/if}
          </label>
          <div class="relative">
            <input
              type="number"
              min="1"
              class="w-full p-3 bg-gray-700/50 text-white pr-10 border border-blue-200/10 rounded-lg focus:outline-none
            focus:border-blue-400/50 transition-colors duration-500"
              bind:value={$transferData.idOrPhone}
            />
            <i
              class="fa-duotone fa-user absolute top-1/2 right-3 transform -translate-y-1/2 text-gray-400"
            ></i>
          </div>
        </div>
      {/if}

      <!-- Amount Input -->
      <div class="mb-6">
        <label class="block text-gray-400 mb-2">
          <i class="fa-duotone fa-money-bill-wave text-blue-400 mr-2"
          ></i>{$Locales.amount}
        </label>
        <div class="relative">
          <input
            type="number"
            min="1"
            class="w-full p-3 bg-gray-700/50 text-white pr-10 border border-blue-200/10 rounded-lg focus:outline-none
            focus:border-blue-400/50 transition-colors duration-500"
            bind:value={$transferData.amount}
          />
          <i
            class="fa-duotone fa-dollar-sign absolute top-1/2 right-3 transform -translate-y-1/2 text-gray-400"
          ></i>
        </div>
      </div>

      <!-- Action Buttons -->
      <div class="flex justify-between items-center mt-6">
        <button
          class="flex items-center bg-red-600 hover:bg-red-700 text-white py-2 px-4 rounded focus:outline-none"
          on:click={closeModal}
        >
          <i class="fa-duotone fa-times-circle mr-2"></i>{$Locales.cancel}
        </button>
        <button
          class="flex items-center bg-blue-600 hover:bg-blue-700 text-white py-2 px-4 rounded focus:outline-none"
          on:click={async () => {
            confirmTransfer(
              $transferData.idOrPhone,
              $transferData.amount,
              $transferData.contactType
            );
          }}
        >
          <i class="fa-duotone fa-check-circle mr-2"></i>{$Locales.confirm}
        </button>
      </div>
    </div>
  </div>
{/if}
{#if $showSureModalBills}
  <div
    class="fixed inset-0 flex items-center justify-center bg-black bg-opacity-50"
  >
    <div
      class="bg-gray-700 p-8 rounded-lg shadow-lg w-96"
      in:scale={{ duration: 250, easing: quintOut }}
      out:scale={{ duration: 250, easing: quintOut }}
    >
      <div class="flex items-center mb-4">
        <i class="fa-duotone fa-question-circle text-3xl text-blue-400 mr-3"
        ></i>
        <h2 class="text-2xl text-blue-200 font-bold">
          {$Locales.are_you_sure}
        </h2>
      </div>
      <p class="text-gray-300 mb-6">
        {$Locales.confirm_pay_all_bills}
      </p>
      <div class="flex justify-between items-center">
        <button
          class="flex items-center bg-red-600 hover:bg-red-700 text-white py-2 px-4 rounded focus:outline-none"
          on:click={() => {
            showSureModalBills.set(false);
          }}
        >
          <i class="fa-duotone fa-times-circle mr-2"></i>{$Locales.cancel}
        </button>
        <button
          class="flex items-center bg-blue-600 hover:bg-blue-700 text-white py-2 px-4 rounded focus:outline-none"
          on:click={async () => {
            if ($transactions.length > 0) {
              await payAllBills();
              showSureModalBills.set(false);
            } else {
              showSureModalBills.set(false);
              Notify(
                $Locales.pay_all_bills_error,
                $Locales.error,
                "circle-exclamation"
              );
            }
          }}
        >
          <i class="fa-duotone fa-check-circle mr-2"></i>{$Locales.confirm}
        </button>
      </div>
    </div>
  </div>
{/if}
