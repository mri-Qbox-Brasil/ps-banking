<script lang="ts">
  import { onMount } from "svelte";
  import { writable } from "svelte/store";
  import { slide, fade } from "svelte/transition";
  import { quintOut } from "svelte/easing";
  import { fetchNui } from "../utils/fetchNui";
  import { Notify, Locales, Currency, bankBalance } from "../store/data";

  interface Account {
    id: string;
    name: string;
    balance: number;
    type: string;
    isActive: boolean;
    created: string;
    users?: Array<{name: string, identifier: string}>;
    owner?: {name: string, identifier: string, state: boolean};
  }

  let accounts = writable<Account[]>([]);
  let showCreateModal = writable(false);
  let newAccountName = writable("");
  let newAccountType = writable("savings");

  // Deposit modal state
  let showDepositModal = writable(false);
  let selectedAccountForDeposit = writable<Account | null>(null);
  let depositAmount = writable(0);

  // Add user modal state
  let showAddUserModal = writable(false);
  let selectedAccountForUser = writable<Account | null>(null);
  let userIdToAdd = writable("");
  let isAddingUser = writable(false);

  // Withdraw modal state
  let showWithdrawModal = writable(false);
  let selectedAccountForWithdraw = writable<Account | null>(null);
  let withdrawAmount = writable(0);

  // Remove user modal state
  let showRemoveUserModal = writable(false);
  let selectedAccountForRemove = writable<Account | null>(null);
  let selectedUserToRemove = writable<{name: string, identifier: string} | null>(null);

  async function fetchAccounts() {
      try {
      const response = await fetchNui("ps-banking:client:getAccounts", {});
      console.log("Raw server response:", response); // Debug log
      
      // Validate response
      if (!response || !Array.isArray(response)) {
        console.error("Invalid response format:", response);
        accounts.set([]);
        return;
      }
      
      // Transform server data to match frontend interface
      const transformedAccounts = response.map((account, index) => {
        try {
          console.log(`Processing account ${index}:`, account); // Debug log
          
          // Validate account object
          if (!account || typeof account !== 'object') {
            console.error(`Invalid account at index ${index}:`, account);
            return null;
          }
          
          // Safely extract and validate fields
          const id = account.id ? account.id.toString() : `temp_${index}`;
          const holder = account.holder && typeof account.holder === 'string' ? account.holder : $Locales.unknown_account;
          const balance = typeof account.balance === 'number' ? account.balance : 0;
          
          // Safely extract account type from owner metadata
          let accountType = 'savings';
          try {
            if (account.owner && typeof account.owner === 'object' && account.owner.accountType) {
              accountType = account.owner.accountType;
            }
          } catch (e) {
            console.warn('Failed to extract account type:', e);
          }

          // Safely extract users array
          let users = [];
          try {
            if (account.users && Array.isArray(account.users)) {
              users = account.users.filter(user => 
                user && typeof user === 'object' && user.name && user.identifier
              );
            }
          } catch (e) {
            console.warn('Failed to extract users:', e);
          }

          // Safely extract owner information
          let owner = null;
          try {
            if (account.owner && typeof account.owner === 'object') {
              owner = {
                name: account.owner.name || $Locales.unknown,
                identifier: account.owner.identifier || '',
                state: account.owner.state || false
              };
            }
          } catch (e) {
            console.warn('Failed to extract owner:', e);
          }
          
          return {
            id: id,
            name: holder,
            balance: balance,
            type: accountType,
            isActive: true,
            created: '2024-01-01',
            users: users,
            owner: owner
          };
        } catch (error) {
          console.error(`Error processing account at index ${index}:`, error, account);
          return null;
        }
      }).filter(account => account !== null); // Remove null entries
      
      console.log("Transformed accounts:", transformedAccounts); // Debug log
      safeSetAccounts(transformedAccounts);
      } catch (error) {
        console.error("Error fetching accounts:", error);
        Notify($Locales.failed_fetch_accounts, $Locales.error, "user");
        safeSetAccounts([]); // Set empty array on error
    }
  }

  async function createAccount() {
    if (!$newAccountName.trim()) {
      Notify($Locales.please_enter_account_name, $Locales.error, "user");
      return;
    }

    try {
      // Get user information first
      const user = await fetchNui("ps-banking:client:getUser", {});
      if (!user) {
        Notify($Locales.failed_get_user_info, $Locales.error, "user");
        return;
      }

      // Generate a random card number (16 digits)
      const cardNumber = Math.floor(Math.random() * 9000000000000000) + 1000000000000000;

      // Create the new account object with the expected structure
      const newAccountData = {
        newAccount: {
          balance: 0, // Initial balance
          holder: $newAccountName.trim(),
          cardNumber: cardNumber.toString(),
          users: [], // Empty array for additional users
          owner: {
            name: user.name,
            identifier: user.identifier,
            accountType: $newAccountType // Store the account type here
          }
        }
      };

      const result = await fetchNui("ps-banking:client:createNewAccount", newAccountData);
      console.log("Create account result:", result); // Debug log
      
      if (result && result.success) {
        Notify($Locales.account_created_success, $Locales.success, "user");
        showCreateModal.set(false);
        newAccountName.set("");
        newAccountType.set("savings");
        fetchAccounts();
      } else {
        console.error("Failed to create account:", result); // Debug log
        Notify($Locales.failed_create_account, $Locales.error, "user");
      }
    } catch (error) {
      console.error(error);
      Notify($Locales.failed_create_account, $Locales.error, "user");
    }
  }

  async function deleteAccount(accountId: string) {
    try {
      const result = await fetchNui("ps-banking:client:deleteAccount", {
        accountId: accountId
      });
      
      if (result && result.success) {
        Notify($Locales.account_deleted_success, $Locales.success, "user");
        fetchAccounts();
      } else {
        Notify($Locales.failed_delete_account, $Locales.error, "user");
      }
    } catch (error) {
      console.error(error);
      Notify($Locales.failed_delete_account, $Locales.error, "user");
    }
  }

  async function depositToAccount() {
    if (!$selectedAccountForDeposit || $depositAmount <= 0) {
      Notify($Locales.please_enter_valid_amount, $Locales.error, "user");
      return;
    }

    try {
      const result = await fetchNui("ps-banking:client:depositToAccount", {
        accountId: parseInt($selectedAccountForDeposit.id),
        amount: $depositAmount
      });

      if (result && result.success) {
        Notify(`R$ ${$depositAmount.toLocaleString()} ${$Locales.deposited_successfully}`, $Locales.success, "user");
        showDepositModal.set(false);
        depositAmount.set(0);
        selectedAccountForDeposit.set(null);
        fetchAccounts();
        // Refresh money types to update bank balance
        updateMoneyTypes();
      } else {
        Notify($Locales.insufficient_funds_deposit, $Locales.error, "user");
      }
    } catch (error) {
      console.error(error);
      Notify($Locales.failed_deposit_account, $Locales.error, "user");
    }
  }

  async function withdrawFromAccount() {
    if (!$selectedAccountForWithdraw || $withdrawAmount <= 0) {
      Notify($Locales.please_enter_valid_amount, $Locales.error, "user");
      return;
    }

    try {
      const result = await fetchNui("ps-banking:client:withdrawFromAccount", {
        accountId: parseInt($selectedAccountForWithdraw.id),
        amount: $withdrawAmount
      });

      if (result && result.success) {
        Notify(`R$ ${$withdrawAmount.toLocaleString()} ${$Locales.withdrew_successfully}`, $Locales.success, "user");
        showWithdrawModal.set(false);
        withdrawAmount.set(0);
        selectedAccountForWithdraw.set(null);
        fetchAccounts();
        // Refresh money types to update bank balance
        updateMoneyTypes();
      } else {
        Notify($Locales.insufficient_funds_account, $Locales.error, "user");
      }
    } catch (error) {
      console.error(error);
      Notify($Locales.failed_withdraw_account, $Locales.error, "user");
    }
  }

  async function addUserToAccount() {
    // Validate inputs with proper type checking
    if (!$selectedAccountForUser || !$userIdToAdd) {
      Notify($Locales.please_enter_valid_user_id, $Locales.error, "user");
      return;
    }

    // Convert to string and trim safely
    const userIdString = String($userIdToAdd || '').trim();
    if (!userIdString) {
      Notify($Locales.please_enter_valid_user_id, $Locales.error, "user");
      return;
    }

    const playerId = parseInt(userIdString);
    if (isNaN(playerId) || playerId <= 0) {
      Notify($Locales.please_enter_valid_numeric_player_id, $Locales.error, "user");
      return;
    }

    // Set loading state
    isAddingUser.set(true);

    try {
      // Add a timeout to prevent infinite waiting
      const timeoutPromise = new Promise((_, reject) => 
        setTimeout(() => reject(new Error('Request timeout')), 10000)
      );

      const apiPromise = fetchNui("ps-banking:client:addUserToAccount", {
        accountId: parseInt($selectedAccountForUser.id),
        userId: playerId
      });

      const result = await Promise.race([apiPromise, timeoutPromise]);
      console.log("Add user result:", result); // Debug log

      // Handle the response properly
      if (result && typeof result === 'object') {
        if (result.success === true) {
          const userName = result.userName || "Player";
          Notify(`${userName} ${$Locales.added_to_account_successfully}`, $Locales.success, "user");
          safeCloseModal('addUser');
          fetchAccounts();
        } else {
          // Handle specific error messages
          let errorMessage = $Locales.failed_add_user;
          
          if (result.message) {
            if (result.message.includes("target_player_not_found") || result.message.includes("not found")) {
              errorMessage = $Locales.player_not_found_offline;
            } else if (result.message.includes("cannot_add_self")) {
                              errorMessage = $Locales.cannot_add_yourself;
            } else if (result.message.includes("user_already_in_account")) {
                              errorMessage = $Locales.player_already_added;
            } else {
              errorMessage = result.message;
            }
          }
          
          Notify(errorMessage, $Locales.error, "user");
          console.error("Add user failed:", result);
        }
      } else {
        Notify($Locales.failed_add_user_invalid_response, $Locales.error, "user");
        console.error("Invalid response:", result);
      }
    } catch (error) {
      console.error("Add user error:", error);
      
      if (error.message === 'Request timeout') {
        Notify($Locales.request_timed_out, $Locales.error, "user");
      } else {
        Notify($Locales.failed_add_user, $Locales.error, "user");
      }
      
      // Ensure modal stays responsive even on error
      safeCloseModal('addUser');
    } finally {
      // Always reset loading state
      try {
        isAddingUser.set(false);
      } catch (e) {
        console.error("Error resetting loading state:", e);
      }
    }
  }

  async function removeUserFromAccount() {
    if (!$selectedAccountForRemove || !$selectedUserToRemove) {
      Notify("Please select a user to remove", $Locales.error, "user");
      return;
    }

    try {
      const result = await fetchNui("ps-banking:client:removeUserFromAccount", {
        accountId: parseInt($selectedAccountForRemove.id),
        user: $selectedUserToRemove.identifier
      });

      console.log("Remove user result:", result); // Debug log

      if (result && result.success) {
        Notify(`${$selectedUserToRemove.name} ${$Locales.removed_from_account_successfully}`, $Locales.success, "user");
        safeCloseModal('removeUser');
        fetchAccounts();
      } else {
        Notify($Locales.failed_remove_user, $Locales.error, "user");
        console.error("Remove user failed:", result);
      }
    } catch (error) {
      console.error("Remove user error:", error);
      Notify($Locales.failed_remove_user, $Locales.error, "user");
      safeCloseModal('removeUser');
    }
  }

  function openDepositModal(account: Account) {
    selectedAccountForDeposit.set(account);
    depositAmount.set(0);
    showDepositModal.set(true);
  }

  function openAddUserModal(account: Account) {
    selectedAccountForUser.set(account);
    userIdToAdd.set("");
    showAddUserModal.set(true);
  }

  function openRemoveUserModal(account: Account) {
    selectedAccountForRemove.set(account);
    selectedUserToRemove.set(null);
    showRemoveUserModal.set(true);
  }

  function closeAddUserModal() {
    if (!$isAddingUser) {
      safeCloseModal('addUser');
    }
  }

  // Handle ESC key for modals
  function handleKeydown(event: KeyboardEvent) {
    if (event.key === 'Escape') {
      if ($showAddUserModal && !$isAddingUser) {
        closeAddUserModal();
      } else if ($showRemoveUserModal) {
        safeCloseModal('removeUser');
      } else if ($showDepositModal) {
        showDepositModal.set(false);
      } else if ($showWithdrawModal) {
        showWithdrawModal.set(false);
      } else if ($showCreateModal) {
        showCreateModal.set(false);
      }
    }
  }

  function openWithdrawModal(account: Account) {
    selectedAccountForWithdraw.set(account);
    withdrawAmount.set(0);
    showWithdrawModal.set(true);
  }

  async function updateMoneyTypes() {
    try {
      const response = await fetchNui("ps-banking:client:getMoneyTypes", {});
      const bank = response.find((item: { name: string }) => item.name === "bank");
      if (bank) {
        bankBalance.set(bank.amount);
      }
    } catch (error) {
      console.error("Failed to update money types:", error);
    }
  }

  function formatDate(dateString: string) {
    return new Date(dateString).toLocaleDateString();
  }

  // Safe store update functions
  function safeSetAccounts(newAccounts) {
    try {
      if (Array.isArray(newAccounts)) {
        accounts.set(newAccounts);
      } else {
        console.error("Invalid accounts data:", newAccounts);
        accounts.set([]);
      }
    } catch (error) {
      console.error("Error setting accounts:", error);
      accounts.set([]);
    }
  }

  function safeCloseModal(modalName) {
    try {
      switch (modalName) {
        case 'addUser':
          showAddUserModal.set(false);
          userIdToAdd.set("");
          selectedAccountForUser.set(null);
          isAddingUser.set(false);
          break;
        case 'removeUser':
          showRemoveUserModal.set(false);
          selectedAccountForRemove.set(null);
          selectedUserToRemove.set(null);
          break;
        case 'deposit':
          showDepositModal.set(false);
          depositAmount.set(0);
          selectedAccountForDeposit.set(null);
          break;
        case 'withdraw':
          showWithdrawModal.set(false);
          withdrawAmount.set(0);
          selectedAccountForWithdraw.set(null);
          break;
        case 'create':
          showCreateModal.set(false);
          newAccountName.set("");
          newAccountType.set("savings");
          break;
      }
    } catch (error) {
      console.error(`Error closing ${modalName} modal:`, error);
    }
  }

  onMount(() => {
    // Add global error handler
    const handleGlobalError = (event) => {
      console.error("Global error caught:", event.error);
      Notify("An error occurred. Please try again.", $Locales.error, "user");
      
      // Reset modal states to prevent UI freezing
      showAddUserModal.set(false);
      showRemoveUserModal.set(false);
      showDepositModal.set(false);
      showWithdrawModal.set(false);
      showCreateModal.set(false);
      isAddingUser.set(false);
    };

    window.addEventListener('error', handleGlobalError);
    window.addEventListener('unhandledrejection', (event) => {
      console.error("Unhandled promise rejection:", event.reason);
      Notify("An error occurred. Please try again.", $Locales.error, "user");
      
      // Reset modal states
      showAddUserModal.set(false);
      showRemoveUserModal.set(false);
      showDepositModal.set(false);
      showWithdrawModal.set(false);
      showCreateModal.set(false);
      isAddingUser.set(false);
    });
    
    // Fetch accounts with error handling
    try {
      fetchAccounts();
    } catch (error) {
      console.error("Error in initial fetchAccounts:", error);
      Notify($Locales.failed_load_accounts, $Locales.error, "user");
    }
    
    // Add keydown event listener
    document.addEventListener('keydown', handleKeydown);
    
    return () => {
      // Cleanup event listeners
      document.removeEventListener('keydown', handleKeydown);
      window.removeEventListener('error', handleGlobalError);
    };
  });
</script>

<div class="h-full flex flex-col p-8 overflow-y-auto">
  <!-- Page Header -->
  <div class="flex items-center justify-between mb-8">
    <div>
      <h1 class="text-3xl font-bold text-white mb-2">{$Locales.accounts}</h1>
      <p class="text-white/60">{$Locales.manage_bank_accounts_savings}</p>
      </div>
    <div class="flex items-center space-x-4">
      <div class="modern-card px-4 py-2">
        <div class="flex items-center space-x-2">
          <i class="fas fa-piggy-bank text-green-400"></i>
          <span class="text-sm text-white/80">{$accounts.length} {$Locales.accounts}</span>
          </div>
      </div>
      <button
        class="action-button flex items-center space-x-2"
        on:click={() => showCreateModal.set(true)}
      >
        <i class="fas fa-plus"></i>
        <span>{$Locales.create_account}</span>
      </button>
    </div>
  </div>

  <!-- Primary Account -->
  <div class="mb-8">
    <div class="modern-card p-6">
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <div class="w-12 h-12 bg-blue-500/20 rounded-xl flex items-center justify-center">
            <i class="fas fa-piggy-bank text-blue-400 text-lg"></i>
          </div>
          <div>
            <h3 class="text-xl font-semibold text-white">{$Locales.primary_account}</h3>
            <p class="text-white/60 text-sm">{$Locales.main_checking_account}</p>
</div>
        </div>
        <div class="text-right">
          <p class="text-sm text-white/60">{$Locales.current_balance}</p>
          <p class="text-2xl font-bold text-white">
            {#if $bankBalance >= 1000000}
              ${($bankBalance / 1000000).toFixed(1)}M
            {:else if $bankBalance >= 1000}
              ${($bankBalance / 1000).toFixed(1)}K
            {:else}
              ${$bankBalance.toLocaleString()}
{/if}
          </p>
        </div>
      </div>
    </div>
  </div>

  <!-- Secondary Accounts -->
  <div class="grid gap-4">
    {#if $accounts.length > 0}
      {#each $accounts as account (account.id)}
        <div
          class="modern-card modern-card-hover p-6"
          in:fade={{ duration: 300 }}
          out:slide={{ duration: 300 }}
        >
          <div class="flex items-center justify-between">
            <div class="flex items-center space-x-4 flex-1">
              <div class={`w-12 h-12 rounded-xl flex items-center justify-center ${
                account.type === 'savings' 
                  ? 'bg-green-500/20' 
                  : account.type === 'business'
                  ? 'bg-green-500/20'
                  : 'bg-orange-500/20'
              }`}>
                <i class={`fas ${
                  account.type === 'savings' 
                    ? 'fa-piggy-bank text-green-400' 
                    : account.type === 'business'
                    ? 'fa-briefcase text-green-400'
                    : 'fa-wallet text-orange-400'
                } text-lg`}></i>
              </div>
              
              <div class="flex-1 min-w-0">
                <div class="flex items-center space-x-2 mb-1">
                  <h3 class="text-white font-semibold truncate">{account.name}</h3>
                  {#if account.isActive}
                    <span class="px-2 py-1 bg-green-500/20 rounded-full text-green-400 text-xs">{$Locales.active}</span>
                  {:else}
                    <span class="px-2 py-1 bg-red-500/20 rounded-full text-red-400 text-xs">{$Locales.inactive}</span>
                  {/if}
                </div>
                <div class="flex items-center space-x-4 text-sm text-white/60">
                  <span class="capitalize">{account.type} {$Locales.account_suffix}</span>
                  <span>{$Locales.created} {formatDate(account.created)}</span>
                </div>
              </div>
            </div>

            <div class="flex items-center space-x-4">
              <div class="text-right">
                <p class="text-sm text-white/60">{$Locales.balance}</p>
                <p class="text-xl font-bold text-white">
                  {#if account.balance >= 1000000}
                    ${(account.balance / 1000000).toFixed(1)}M
                  {:else if account.balance >= 1000}
                    ${(account.balance / 1000).toFixed(1)}K
                  {:else}
                    ${account.balance.toLocaleString()}
                  {/if}
                </p>
              </div>

              <div class="flex space-x-2">
                <button
                  class="p-2 bg-blue-500/20 rounded-lg text-blue-400 hover:bg-blue-500/30 transition-colors"
                  title={$Locales.view_details}
                >
                  <i class="fas fa-eye"></i>
                </button>
                <button
                  class="p-2 bg-green-500/20 rounded-lg text-green-400 hover:bg-green-500/30 transition-colors"
                  title={$Locales.deposit_money}
                  on:click={() => openDepositModal(account)}
                >
                  <i class="fas fa-plus"></i>
                </button>
                <button
                  class="p-2 bg-orange-500/20 rounded-lg text-orange-400 hover:bg-orange-500/30 transition-colors"
                  title={$Locales.withdraw_money}
                  on:click={() => openWithdrawModal(account)}
                >
                  <i class="fas fa-minus"></i>
                </button>
                <button
                  class="p-2 bg-green-500/20 rounded-lg text-green-400 hover:bg-green-500/30 transition-colors"
                  title={$Locales.add_user}
                  on:click={() => openAddUserModal(account)}
                >
                  <i class="fas fa-user-plus"></i>
                </button>
                {#if account.users && account.users.length > 0}
                  <button
                    class="p-2 bg-yellow-500/20 rounded-lg text-yellow-400 hover:bg-yellow-500/30 transition-colors"
                    title={$Locales.remove_user}
                    on:click={() => openRemoveUserModal(account)}
                  >
                    <i class="fas fa-user-minus"></i>
                  </button>
                {/if}
                <button
                  class="p-2 bg-red-500/20 rounded-lg text-red-400 hover:bg-red-500/30 transition-colors"
                  title={$Locales.delete_account}
                  on:click={() => deleteAccount(account.id)}
                >
                  <i class="fas fa-trash"></i>
                </button>
              </div>
            </div>
          </div>

          <!-- Users section -->
          {#if account.users && account.users.length > 0}
            <div class="mt-3 pt-3 border-t border-white/10">
              <div class="text-white/80 text-xs font-medium mb-2">
                {$Locales.shared_with} ({account.users.length}):
              </div>
              <div class="flex flex-wrap gap-1">
                {#each account.users as user}
                  <span class="px-2 py-1 bg-green-500/20 text-green-300 text-xs rounded-lg">
                    <i class="fas fa-user mr-1"></i>{user.name}
                  </span>
                {/each}
              </div>
            </div>
          {/if}
          
          <!-- Owner indicator -->
          {#if account.owner}
            <div class="mt-2 text-xs text-white/60">
              {#if account.owner.state}
                <i class="fas fa-crown text-yellow-400 mr-1"></i>{$Locales.owner_you}
              {:else}
                                  <i class="fas fa-users text-blue-400 mr-1"></i>{$Locales.shared_account}
              {/if}
            </div>
          {/if}
        </div>
      {/each}
    {:else}
      <div class="modern-card p-12 text-center">
        <i class="fas fa-piggy-bank text-white/30 text-5xl mb-4"></i>
        <h3 class="text-xl font-semibold text-white mb-2">{$Locales.no_additional_accounts}</h3>
        <p class="text-white/60 mb-6">{$Locales.create_savings_business_account}</p>
        <button
          class="action-button"
          on:click={() => showCreateModal.set(true)}
        >
          <i class="fas fa-plus mr-2"></i>
          {$Locales.create_your_first_account}
        </button>
      </div>
    {/if}
  </div>
</div>

<!-- Create Account Modal -->
{#if $showCreateModal}
  <div class="modal-w fixed inset-0 flex items-center justify-center z-50">
    <div
      class="modern-card p-8 w-full max-w-md mx-4"
      in:fade={{ duration: 300 }}
      out:fade={{ duration: 250 }}
    >
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-2xl font-bold text-white">{$Locales.create_new_account}</h2>
        <button
          class="p-2 hover:bg-white/10 rounded-lg transition-colors"
          on:click={() => showCreateModal.set(false)}
        >
          <i class="fas fa-times text-white/60"></i>
        </button>
      </div>

      <div class="space-y-4">
        <div>
          <label class="block text-white/80 text-sm font-medium mb-2">{$Locales.account_name}</label>
          <input
            type="text"
            class="w-full bg-white/5 text-white px-4 py-3 rounded-xl border border-white/10 focus:outline-none focus:border-blue-500/50 transition-colors"
            placeholder={$Locales.enter_account_name}
            bind:value={$newAccountName}
          />
        </div>

        <div>
          <label class="block text-white/80 text-sm font-medium mb-2">{$Locales.account_type}</label>
          <select
            class="w-full bg-white/5 text-white px-4 py-3 rounded-xl border border-white/10 focus:outline-none focus:border-blue-500/50 transition-colors"
            bind:value={$newAccountType}
          >
            <option value="savings">{$Locales.savings_account}</option>
            <option value="business">{$Locales.business_account}</option>
            <option value="investment">{$Locales.investment_account}</option>
          </select>
        </div>
      </div>

      <div class="flex space-x-4 mt-8">
        <button
          class="flex-1 px-4 py-3 bg-white/10 rounded-xl text-white hover:bg-white/20 transition-colors"
          on:click={() => showCreateModal.set(false)}
        >
          {$Locales.cancel}
        </button>
        <button
          class="flex-1 action-button"
          on:click={createAccount}
          disabled={!$newAccountName.trim()}
        >
          {$Locales.create_account}
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Deposit Modal -->
{#if $showDepositModal && $selectedAccountForDeposit}
  <div class="modal-backdrop fixed inset-0 flex items-center justify-center z-50">
    <div
      class="modern-card p-8 w-full max-w-md mx-4"
      in:fade={{ duration: 300 }}
      out:fade={{ duration: 250 }}
    >
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-2xl font-bold text-white">{$Locales.deposit_money}</h2>
        <button
          class="p-2 hover:bg-white/10 rounded-lg transition-colors"
          on:click={() => showDepositModal.set(false)}
        >
          <i class="fas fa-times text-white/60"></i>
        </button>
      </div>

      <div class="space-y-4">
        <div>
          <label class="block text-white/80 text-sm font-medium mb-2">{$Locales.account}</label>
          <div class="w-full bg-white/5 text-white px-4 py-3 rounded-xl border border-white/10">
            {$selectedAccountForDeposit.name}
          </div>
        </div>

        <div>
          <label class="block text-white/80 text-sm font-medium mb-2">{$Locales.amount_to_deposit}</label>
          <input
            type="number"
            class="w-full bg-white/5 text-white px-4 py-3 rounded-xl border border-white/10 focus:outline-none focus:border-green-500/50 transition-colors"
            placeholder={$Locales.enter_amount}
            bind:value={$depositAmount}
            min="1"
            max={$bankBalance}
          />
          <p class="text-white/60 text-sm mt-2">{$Locales.available}: R$ {$bankBalance.toLocaleString()}</p>
        </div>
      </div>

      <div class="flex space-x-4 mt-8">
        <button
          class="flex-1 px-4 py-3 bg-white/10 rounded-xl text-white hover:bg-white/20 transition-colors"
          on:click={() => showDepositModal.set(false)}
        >
          {$Locales.cancel}
        </button>
        <button
          class="flex-1 action-button bg-green-500/10 border-green-500/30 hover:bg-green-500/20"
          on:click={depositToAccount}
          disabled={$depositAmount <= 0 || $depositAmount > $bankBalance}
        >
          {$Locales.deposit}
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Add User Modal -->
{#if $showAddUserModal && $selectedAccountForUser}
  <div class="modal-backdrop fixed inset-0 flex items-center justify-center z-50">
    <div
      class="modern-card p-8 w-full max-w-md mx-4"
      in:fade={{ duration: 300 }}
      out:fade={{ duration: 250 }}
    >
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-2xl font-bold text-white">{$Locales.add_user_to_account}</h2>
        <button
          class="p-2 hover:bg-white/10 rounded-lg transition-colors"
          on:click={closeAddUserModal}
          disabled={$isAddingUser}
        >
          <i class="fas fa-times text-white/60"></i>
        </button>
      </div>

      <div class="space-y-4">
        <div>
          <label class="block text-white/80 text-sm font-medium mb-2">{$Locales.account}</label>
          <div class="w-full bg-white/5 text-white px-4 py-3 rounded-xl border border-white/10">
            {$selectedAccountForUser.name}
          </div>
        </div>

        <div>
          <label class="block text-white/80 text-sm font-medium mb-2">{$Locales.player_id}</label>
          <input
            type="number"
            class="w-full bg-white/5 text-white px-4 py-3 rounded-xl border border-white/10 focus:outline-none focus:border-green-500/50 transition-colors"
            placeholder={$Locales.enter_player_server_id}
            bind:value={$userIdToAdd}
            min="1"
            max="9999"
            disabled={$isAddingUser}
            on:keydown={(e) => {
              if (e.key === 'Enter' && !$isAddingUser && String($userIdToAdd || '').trim()) {
                addUserToAccount();
              }
            }}
          />
          <p class="text-white/60 text-sm mt-2">
            {#if $userIdToAdd && (isNaN(parseInt(String($userIdToAdd))) || parseInt(String($userIdToAdd)) <= 0)}
                              <span class="text-red-400">⚠️ {$Locales.please_enter_valid_numeric_player_id}</span>
            {:else}
                              {$Locales.enter_server_id_instruction}
            {/if}
          </p>
        </div>
      </div>

      <div class="flex space-x-4 mt-8">
        <button
          class="flex-1 px-4 py-3 bg-white/10 rounded-xl text-white hover:bg-white/20 transition-colors"
          on:click={closeAddUserModal}
          disabled={$isAddingUser}
        >
          {$Locales.cancel}
        </button>
        <button
          class="flex-1 action-button bg-green-500/10 border-green-500/30 hover:bg-green-500/20"
          on:click={addUserToAccount}
          disabled={!String($userIdToAdd || '').trim() || $isAddingUser}
        >
          {#if $isAddingUser}
            <i class="fas fa-spinner fa-spin mr-2"></i>
            {$Locales.adding}
          {:else}
            {$Locales.add_user}
          {/if}
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Withdraw Modal -->
{#if $showWithdrawModal && $selectedAccountForWithdraw}
  <div class="modal-backdrop fixed inset-0 flex items-center justify-center z-50">
    <div
      class="modern-card p-8 w-full max-w-md mx-4"
      in:fade={{ duration: 300 }}
      out:fade={{ duration: 250 }}
    >
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-2xl font-bold text-white">{$Locales.withdraw_money}</h2>
        <button
          class="p-2 hover:bg-white/10 rounded-lg transition-colors"
          on:click={() => showWithdrawModal.set(false)}
        >
          <i class="fas fa-times text-white/60"></i>
        </button>
      </div>

      <div class="space-y-4">
        <div>
          <label class="block text-white/80 text-sm font-medium mb-2">{$Locales.account}</label>
          <div class="w-full bg-white/5 text-white px-4 py-3 rounded-xl border border-white/10">
            {$selectedAccountForWithdraw.name}
          </div>
        </div>

        <div>
          <label class="block text-white/80 text-sm font-medium mb-2">{$Locales.amount_to_withdraw}</label>
          <input
            type="number"
            class="w-full bg-white/5 text-white px-4 py-3 rounded-xl border border-white/10 focus:outline-none focus:border-orange-500/50 transition-colors"
            placeholder={$Locales.enter_amount}
            bind:value={$withdrawAmount}
            min="1"
            max={$selectedAccountForWithdraw.balance}
          />
          <p class="text-white/60 text-sm mt-2">{$Locales.available}: R$ {$selectedAccountForWithdraw.balance.toLocaleString()}</p>
        </div>
      </div>

      <div class="flex space-x-4 mt-8">
        <button
          class="flex-1 px-4 py-3 bg-white/10 rounded-xl text-white hover:bg-white/20 transition-colors"
          on:click={() => showWithdrawModal.set(false)}
        >
          {$Locales.cancel}
        </button>
        <button
          class="flex-1 action-button bg-orange-500/10 border-orange-500/30 hover:bg-orange-500/20"
          on:click={withdrawFromAccount}
          disabled={$withdrawAmount <= 0 || $withdrawAmount > $selectedAccountForWithdraw.balance}
        >
          {$Locales.withdraw}
        </button>
      </div>
    </div>
  </div>
{/if}

<!-- Remove User Modal -->
{#if $showRemoveUserModal && $selectedAccountForRemove}
  <div class="modal-backdrop fixed inset-0 flex items-center justify-center z-50">
    <div
      class="modern-card p-8 w-full max-w-md mx-4"
      in:fade={{ duration: 300 }}
      out:fade={{ duration: 250 }}
    >
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-2xl font-bold text-white">{$Locales.remove_user_from_account}</h2>
        <button
          class="p-2 hover:bg-white/10 rounded-lg transition-colors"
          on:click={() => safeCloseModal('removeUser')}
        >
          <i class="fas fa-times text-white/60"></i>
        </button>
      </div>

      <div class="space-y-4">
        <div>
          <label class="block text-white/80 text-sm font-medium mb-2">{$Locales.account}</label>
          <div class="w-full bg-white/5 text-white px-4 py-3 rounded-xl border border-white/10">
            {$selectedAccountForRemove.name}
          </div>
        </div>

        <div>
          <label class="block text-white/80 text-sm font-medium mb-2">{$Locales.select_user_to_remove}</label>
          {#if $selectedAccountForRemove.users && $selectedAccountForRemove.users.length > 0}
            <div class="space-y-2">
              {#each $selectedAccountForRemove.users as user}
                <button
                  class="w-full p-3 rounded-xl border transition-colors text-left {$selectedUserToRemove?.identifier === user.identifier ? 'bg-red-500/20 border-red-500/50 text-red-300' : 'bg-white/5 border-white/10 text-white hover:bg-white/10'}"
                  on:click={() => selectedUserToRemove.set(user)}
                >
                  <div class="flex items-center space-x-3">
                    <i class="fas fa-user text-white/60"></i>
                    <div>
                      <div class="font-medium">{user.name}</div>
                      <div class="text-xs text-white/60">ID: {user.identifier}</div>
                    </div>
                  </div>
                </button>
              {/each}
            </div>
          {:else}
            <div class="text-white/60 text-center py-4">
              {$Locales.no_users_to_remove}
            </div>
          {/if}
        </div>
      </div>

      <div class="flex space-x-4 mt-8">
        <button
          class="flex-1 px-4 py-3 bg-white/10 rounded-xl text-white hover:bg-white/20 transition-colors"
          on:click={() => safeCloseModal('removeUser')}
        >
          {$Locales.cancel}
        </button>
        <button
          class="flex-1 action-button bg-red-500/10 border-red-500/30 hover:bg-red-500/20"
          on:click={removeUserFromAccount}
          disabled={!$selectedUserToRemove}
        >
          <i class="fas fa-user-minus mr-2"></i>
          {$Locales.remove_user}
        </button>
      </div>
    </div>
  </div>
{/if}
