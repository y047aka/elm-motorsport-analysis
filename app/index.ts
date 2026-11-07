import "./src/elements/drag-handle";
import "./src/shadcn/badge-element";
import "./src/shadcn/button-element";
import "./src/shadcn/card-elements";
import "./src/shadcn/slider-element";
import "./src/shadcn/toggle-group-element";
import { Elm } from "./src/Main.elm";

const node = document.getElementById("app");

Elm.Main.init({
  node,
  // `Shared.init` ignores the flags.
  flags: "You can decode this in Shared.elm using Json.Decode.string!",
});
