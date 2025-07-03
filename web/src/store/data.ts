import { writable, type Writable } from "svelte/store";

export interface Notification {
  id: number;
  message: string;
  title: string;
  icon: string;
}

export const notifications = writable<Notification[]>([]);
let notificationId = 0;

export function Notify(message: string, title: string, icon: string) {
  notificationId += 1;
  const newNotification: Notification = {
    id: notificationId,
    message,
    title,
    icon,
  };
  notifications.update((n) => [...n, newNotification]);
  setTimeout(() => {
    notifications.update((n) =>
      n.filter((notification) => notification.id !== newNotification.id)
    );
  }, 2000);
}

export const showOverview = writable(true);
export const showBills = writable(false);
export const showHistory = writable(false);
export const showHeav = writable(false);
export const showIndseat = writable(false);
export const showStats = writable(false);
export const showAccounts = writable(false);
export const showATM = writable(false);
export const currentCash = writable(0);
export const bankBalance = writable(0);

const createActiveViewStore = () => {
  const { subscribe, set, update } = writable('overview');
  
  return {
    subscribe,
    set: (value) => {
      set(value);
    },
    reset: () => set('overview')
  };
};

export const activeView = createActiveViewStore();

export const Currency = writable({
  lang: "pt-BR",
  currency: "BRL",
});

export const Locales = writable({});

export const Transactions: Writable<Array<any>> = writable([
  // {
  //   id: 8,
  //   description: "Åbnede en ny konto",
  //   type: "Fra konto",
  //   amount: 1000,
  //   date: "2022/08/13",
  //   timeAgo: "For 18 timer siden",
  //   isIncome: false,
  // },
  // {
  //   id: 7,
  //   description: "Indsatte 500 DKK på konto",
  //   type: "Til konto",
  //   amount: 500,
  //   date: "2022/08/13",
  //   timeAgo: "For 18 timer siden",
  //   isIncome: true,
  // },
  // {
  //   id: 6,
  //   description: "Indsatte 500 DKK på konto",
  //   type: "Til konto",
  //   amount: 500,
  //   date: "2022/08/13",
  //   timeAgo: "For 18 timer siden",
  //   isIncome: true,
  // },
  // {
  //   id: 5,
  //   description: "Hævede 500 DKK fra en hæveautomat",
  //   type: "Fra konto",
  //   amount: -500,
  //   date: "2022/08/13",
  //   timeAgo: "For 18 timer siden",
  //   isIncome: false,
  // },
  // {
  //   id: 4,
  //   description: "Indsatte 500 DKK på konto",
  //   type: "Til konto",
  //   amount: 500,
  //   date: "2022/08/13",
  //   timeAgo: "For 18 timer siden",
  //   isIncome: true,
  // },
]);

export const Bills: Writable<Array<any>> = writable([
  // {
  //   id: 1,
  //   description: "Mekaniker Regning",
  //   type: "Auto Exotic",
  //   amount: 1000,
  //   date: "2022/08/13",
  //   timeAgo: "For 18 timer siden",
  //   isPaid: false,
  // },
  // {
  //   id: 2,
  //   description: "Mekaniker Regning",
  //   type: "Auto Exotic",
  //   amount: 1000,
  //   date: "2022/08/13",
  //   timeAgo: "For 18 timer siden",
  //   isPaid: false,
  // },
  // {
  //   id: 3,
  //   description: "Mekaniker Regning",
  //   type: "Auto Exotic",
  //   amount: 1000,
  //   date: "2022/08/13",
  //   timeAgo: "For 18 timer siden",
  //   isPaid: false,
  // },
]);
