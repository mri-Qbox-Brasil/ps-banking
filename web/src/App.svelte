<script lang="ts">
  import VisibilityProvider from "./providers/VisibilityProvider.svelte";
  import Main from "./components/Main.svelte";
  import { debugData } from "./utils/debugData";
  import { slide, fade } from "svelte/transition";
  import { notifications } from "../src/store/data";
  import { visibility } from "../src/store/stores";
  import { onMount } from "svelte";
  import { fetchNui } from "./utils/fetchNui";
  import { applyColorConfig, isEnvBrowser } from "./utils/misc";

  // Load color configuration on mount
  onMount(async () => {
    if (!isEnvBrowser()) {
      try {
        const colorConfig = await fetchNui("ps-banking:client:getColorConfig");
        if (colorConfig && colorConfig.color) {
          applyColorConfig(colorConfig.color);
        }
      } catch (error) {
        console.warn("Failed to load color configuration, using defaults:", error);
      }
    }
  });

  debugData([
    {
      action: "openBank",
      data: true,
    },
  ]);
</script>

<main class="relative">
  <VisibilityProvider>
    <Main />
  </VisibilityProvider>
  
  <!-- Modern Notification System -->
  <div class="fixed bottom-20 right-8 flex flex-col gap-4 z-[100] max-w-sm">
    {#each $notifications as notification (notification.id)}
      <div
        class="notification-card p-4 flex items-start space-x-4 min-w-[320px] {notification.title.toLowerCase().includes('error') || notification.title.toLowerCase().includes('erro') ? 'border-red-500/30 bg-red-500/5' : notification.title.toLowerCase().includes('success') || notification.title.toLowerCase().includes('sucesso') ? 'border-green-500/30 bg-green-500/5' : ''}"
        in:slide={{ duration: 400, x: 300 }}
        out:fade={{ duration: 300 }}
      >
        <div class="flex-shrink-0 w-12 h-12 {notification.title.toLowerCase().includes('error') || notification.title.toLowerCase().includes('erro') ? 'bg-red-500/20' : notification.title.toLowerCase().includes('success') || notification.title.toLowerCase().includes('sucesso') ? 'bg-green-500/20' : 'bg-blue-500/20'} rounded-xl flex items-center justify-center">
          <i class="fas fa-{notification.icon} {notification.title.toLowerCase().includes('error') || notification.title.toLowerCase().includes('erro') ? 'text-red-400' : notification.title.toLowerCase().includes('success') || notification.title.toLowerCase().includes('sucesso') ? 'text-green-400' : 'text-blue-400'} text-lg"></i>
        </div>
        <div class="flex-1 min-w-0">
          <h4 class="text-white font-semibold text-sm mb-1">{notification.title}</h4>
          <p class="text-white/80 text-sm leading-relaxed">{notification.message}</p>
        </div>
        <div class="flex-shrink-0">
          <div class="w-2 h-2 {notification.title.toLowerCase().includes('error') || notification.title.toLowerCase().includes('erro') ? 'bg-red-400' : notification.title.toLowerCase().includes('success') || notification.title.toLowerCase().includes('sucesso') ? 'bg-green-400' : 'bg-blue-400'} rounded-full animate-pulse-soft"></div>
        </div>
      </div>
    {/each}
  </div>
</main>
