import "./src/custom-elements/badge-element";
import "./src/custom-elements/button-element";
import "./src/custom-elements/button-group-element";
import "./src/custom-elements/card-elements";
import "./src/custom-elements/slider-element";
import "./src/custom-elements/toggle-group-element";
import { Elm } from "./src/Main.elm";

const node = document.getElementById("app");

Elm.Main.init({
  node,
  // A plain string flag, decoded in Shared.elm (currently ignored there).
  flags: "You can decode this in Shared.elm using Json.Decode.string!",
});
