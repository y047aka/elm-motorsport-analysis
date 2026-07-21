import { Elm } from "./src/Main.elm";

const node = document.getElementById("app");

Elm.Main.init({
  node,
  // A plain string flag, decoded in Shared.elm (currently ignored there).
  flags: "You can decode this in Shared.elm using Json.Decode.string!",
});
