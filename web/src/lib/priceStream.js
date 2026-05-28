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

export function onPriceRefresh(fn) {
  if (!socket) connect();
  listeners.add(fn);
  return () => listeners.delete(fn);
}
