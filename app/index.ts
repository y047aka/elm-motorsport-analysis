import "./src/shadcn/badge-element";
import "./src/shadcn/button-element";
import "./src/shadcn/button-group-element";
import "./src/shadcn/card-elements";
import "./src/shadcn/slider-element";
import "./src/shadcn/toggle-group-element";
import { Elm } from "./src/Main.elm";

// Where the native build's server listens. The page is `tauri://localhost`
// there, so `/api` is this bundle's own export rather than the server, and the
// server has to be named by its origin.
const nativeApi = "http://127.0.0.1:8080";

const isNative = "__TAURI_INTERNALS__" in window;

// The JVM the native build starts takes a moment to answer, so a refused
// connection is waited out. A 503 is not: the server is up and saying it has no
// database, which no amount of waiting changes. Either way the bundle's export
// is there to fall back on.
async function apiBase(): Promise<string> {
  if (!isNative) return "";
  for (let attempt = 0; attempt < 20; attempt++) {
    try {
      const health = await fetch(nativeApi + "/api/health");
      return health.ok ? nativeApi : "";
    } catch {
      await new Promise((resume) => setTimeout(resume, 500));
    }
  }
  return "";
}

const node = document.getElementById("app");

apiBase().then((base) => Elm.Main.init({ node, flags: { apiBase: base } }));
