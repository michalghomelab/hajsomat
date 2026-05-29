// Minimal ActionCable client over a native WebSocket (no @rails/actioncable).
// Subscribes to PricesChannel and calls registered listeners when the server
// pushes a "refreshed" signal. Auto-reconnects on drop.
const IDENTIFIER = JSON.stringify({ channel: "PricesChannel" });
const listeners = new Set();
let socket = null;
let reconnectTimer = null;

function cableUrl() {
  const proto = location.protocol === "https:" ? "wss:" : "ws:";
  return `${proto}//${location.host}/cable`;
}

function connect() {
  // Rage::Cable always selects the actioncable-v1-json subprotocol, so we must
  // offer it or the browser rejects the handshake.
  socket = new WebSocket(cableUrl(), "actioncable-v1-json");

  socket.addEventListener("open", () => {
    socket.send(JSON.stringify({ command: "subscribe", identifier: IDENTIFIER }));
  });

  socket.addEventListener("message", (event) => {
    let data;
    try {
      data = JSON.parse(event.data);
    } catch {
      return;
    }
    if (data.type) return; // welcome / ping / confirm_subscription — ignore
    if (data.message?.type === "refreshed") listeners.forEach((fn) => fn());
  });

  socket.addEventListener("close", scheduleReconnect);
  socket.addEventListener("error", () => socket?.close());
}

function scheduleReconnect() {
  if (reconnectTimer) return;
  reconnectTimer = setTimeout(() => {
    reconnectTimer = null;
    connect();
  }, 3000);
}

function ensureConnected() {
  const live = socket && (socket.readyState === WebSocket.OPEN || socket.readyState === WebSocket.CONNECTING);
  if (live) return;
  clearTimeout(reconnectTimer);
  reconnectTimer = null;
  connect();
}

// Re-sync when the tab/PWA returns to the foreground. Mobile suspends JS and
// drops the socket while backgrounded, and the server only pushes on its next
// refresh — so on resume we reconnect immediately and pull fresh data now
// (firing the same listeners a "refreshed" push would) instead of showing stale
// values until the next server tick. We listen on three events because no single
// one fires reliably everywhere: visibilitychange (tab switch), pageshow (mobile
// bfcache restore — common for installed PWAs), and focus (desktop).
let lastResume = 0;
function resume() {
  if (typeof document !== "undefined" && document.visibilityState === "hidden") return;
  const now = Date.now();
  if (now - lastResume < 1000) return; // the three events often fire together
  lastResume = now;
  ensureConnected();
  listeners.forEach((fn) => fn());
}
if (typeof window !== "undefined") {
  document.addEventListener("visibilitychange", resume);
  window.addEventListener("pageshow", resume);
  window.addEventListener("focus", resume);
}

export function onPriceRefresh(fn) {
  ensureConnected();
  listeners.add(fn);
  return () => listeners.delete(fn);
}
