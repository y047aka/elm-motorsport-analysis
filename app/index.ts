type ElmPagesInit = {
  load: (elmLoaded: Promise<unknown>) => Promise<void>;
  flags: unknown;
};

type ElmApp = {
  ports?: {
    connectLiveTiming?: {
      subscribe: (callback: (url: string) => void) => void;
    };
    disconnectLiveTiming?: {
      subscribe: (callback: () => void) => void;
    };
    liveTimingMessage?: {
      send: (data: unknown) => void;
    };
  };
};

// WebSocket connection management
let wsConnection: WebSocket | null = null;
let reconnectTimer: ReturnType<typeof setTimeout> | null = null;
let reconnectAttempts = 0;
const MAX_RECONNECT_ATTEMPTS = 10;
const INITIAL_RECONNECT_DELAY = 1000;

function connectWebSocket(app: ElmApp, url: string) {
  // Clear any existing connection
  if (wsConnection) {
    wsConnection.close();
    wsConnection = null;
  }

  // Clear any pending reconnect
  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
    reconnectTimer = null;
  }

  console.log(`[LiveTiming] Connecting to ${url}...`);

  try {
    wsConnection = new WebSocket(url);

    wsConnection.onopen = () => {
      console.log("[LiveTiming] Connected");
      reconnectAttempts = 0;

      // Notify Elm of successful connection
      if (app.ports?.liveTimingMessage?.send) {
        app.ports.liveTimingMessage.send({
          type: "connected",
          timestamp: Date.now(),
        });
      }
    };

    wsConnection.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data);
        console.log("[LiveTiming] Message received:", data);

        if (app.ports?.liveTimingMessage?.send) {
          app.ports.liveTimingMessage.send({
            type: "data",
            payload: data,
            timestamp: Date.now(),
          });
        }
      } catch (error) {
        console.error("[LiveTiming] Failed to parse message:", error);
        if (app.ports?.liveTimingMessage?.send) {
          app.ports.liveTimingMessage.send({
            type: "error",
            error: "Failed to parse message",
            timestamp: Date.now(),
          });
        }
      }
    };

    wsConnection.onerror = (error) => {
      console.error("[LiveTiming] WebSocket error:", error);
      if (app.ports?.liveTimingMessage?.send) {
        app.ports.liveTimingMessage.send({
          type: "error",
          error: "WebSocket error",
          timestamp: Date.now(),
        });
      }
    };

    wsConnection.onclose = (event) => {
      console.log(`[LiveTiming] Disconnected (code: ${event.code}, reason: ${event.reason})`);
      wsConnection = null;

      if (app.ports?.liveTimingMessage?.send) {
        app.ports.liveTimingMessage.send({
          type: "disconnected",
          code: event.code,
          reason: event.reason,
          timestamp: Date.now(),
        });
      }

      // Attempt to reconnect with exponential backoff
      if (reconnectAttempts < MAX_RECONNECT_ATTEMPTS && !event.wasClean) {
        const delay = INITIAL_RECONNECT_DELAY * Math.pow(2, reconnectAttempts);
        reconnectAttempts++;

        console.log(`[LiveTiming] Reconnecting in ${delay}ms (attempt ${reconnectAttempts}/${MAX_RECONNECT_ATTEMPTS})...`);

        reconnectTimer = setTimeout(() => {
          connectWebSocket(app, url);
        }, delay);
      }
    };
  } catch (error) {
    console.error("[LiveTiming] Failed to create WebSocket:", error);
    if (app.ports?.liveTimingMessage?.send) {
      app.ports.liveTimingMessage.send({
        type: "error",
        error: `Failed to create WebSocket: ${error}`,
        timestamp: Date.now(),
      });
    }
  }
}

function disconnectWebSocket() {
  console.log("[LiveTiming] Manually disconnecting...");

  // Clear reconnect timer
  if (reconnectTimer) {
    clearTimeout(reconnectTimer);
    reconnectTimer = null;
  }

  // Close connection
  if (wsConnection) {
    wsConnection.close(1000, "Client disconnected");
    wsConnection = null;
  }

  reconnectAttempts = 0;
}

const config: ElmPagesInit = {
  load: async function (elmLoaded) {
    const app = await elmLoaded as ElmApp;
    console.log("App loaded", app);

    // Setup WebSocket ports
    if (app.ports?.connectLiveTiming?.subscribe) {
      app.ports.connectLiveTiming.subscribe((url: string) => {
        console.log("[LiveTiming] Port: connectLiveTiming called with URL:", url);
        connectWebSocket(app, url);
      });
    }

    if (app.ports?.disconnectLiveTiming?.subscribe) {
      app.ports.disconnectLiveTiming.subscribe(() => {
        console.log("[LiveTiming] Port: disconnectLiveTiming called");
        disconnectWebSocket();
      });
    }

    // Cleanup on page unload
    window.addEventListener("beforeunload", () => {
      disconnectWebSocket();
    });
  },
  flags: function () {
    return "You can decode this in Shared.elm using Json.Decode.string!";
  },
};

export default config;
