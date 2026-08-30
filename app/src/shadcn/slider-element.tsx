import { Slider } from "./ui/slider";
import { ReactElement } from "./react-element";

/**
 * Wraps shadcn's slider so Elm can drive it. `value` comes in as a property
 * and a drag leaves as a `slider-change` event; the element keeps no position
 * of its own, so the clock moves the thumb even while a drag is in progress.
 */
export class ShadcnSlider extends ReactElement {
  private _value = 0;
  private _min = 0;
  private _max = 100;

  set value(v: number) {
    this._value = Number(v) || 0;
    this.update();
  }
  get value() {
    return this._value;
  }

  set min(v: number) {
    this._min = Number(v) || 0;
    this.update();
  }

  set max(v: number) {
    this._max = Number(v) || 0;
    this.update();
  }

  protected draw() {
    return (
      <Slider
        // A bare number leaves shadcn's wrapper falling back to [min, max],
        // which draws the two thumbs of a range slider; a one-element array is
        // what asks for a single thumb.
        value={[this._value]}
        min={this._min}
        max={this._max}
        onValueChange={(next) => {
          const value = Array.isArray(next) ? next[0] : next;
          this.dispatchEvent(
            new CustomEvent("slider-change", { detail: value })
          );
        }}
      />
    );
  }
}

customElements.define("shadcn-slider", ShadcnSlider);
