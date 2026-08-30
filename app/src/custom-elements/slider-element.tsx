import { Slider } from "./shadcn/slider";
import { ReactElement } from "./react-element";

/**
 * Wraps shadcn's Base UI slider so Elm can drive it.
 *
 * React renders into the light DOM rather than a shadow root, so the page's
 * Tailwind reaches the track and thumb; the element takes no children, so
 * neither side has to share nodes with the other.
 *
 * `value` comes in as a property and a drag leaves as a `slider-change` event.
 * The element keeps no position of its own: the clock owns it, and a frame that
 * moves the clock has to move the thumb even while a drag is in progress.
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
