import "./src/elements/drag-handle";
import "./src/shadcn/badge-element";
import "./src/shadcn/button-element";
import "./src/shadcn/card-elements";
import "./src/shadcn/slider-element";
import "./src/shadcn/toggle-group-element";
import { Elm } from "./src/Main.elm";
import leMans from "../circuits/le_mans/map-2026.json";

const node = document.getElementById("app");

Elm.Main.init({
  node,
  // The latest map of each circuit whose lines the drawing places, read by `Shared.init`.
  flags: { leMans },
});
