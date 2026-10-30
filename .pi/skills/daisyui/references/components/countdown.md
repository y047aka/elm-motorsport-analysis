# Countdown

Animated number display component with transition effects for timer and counter use cases.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `countdown` | Component | Wrapper that enables transition effects when the `--value` CSS variable changes |

## Essential Examples

### Basic usage

```html
<span class="countdown">
  <span style="--value:59;">59</span>
</span>
```

### With structure

```html
<!-- Clock format HH:MM:SS -->
<span class="countdown font-mono text-2xl">
  <span style="--value:10;">10</span>:
  <span style="--value:24; --digits:2;">24</span>:
  <span style="--value:59; --digits:2;">59</span>
</span>
```

### Interactive

```html
<!-- Dynamic countdown requires JavaScript to update --value and text content -->
<span class="countdown font-mono text-6xl" id="countdown-display">
  <span id="countdown-value" style="--value:59;" aria-live="polite" aria-label="59">59</span>
</span>

<script>
  const el = document.getElementById("countdown-value");
  let value = 59;
  const interval = setInterval(() => {
    value--;
    if (value < 0) { clearInterval(interval); return; }
    el.style.setProperty("--value", value);
    el.textContent = value;
    el.setAttribute("aria-label", String(value));
  }, 1000);
</script>
```

## Notes

- **Required**: Both the CSS custom property `--value` and the text content of the span must be updated together for the display to stay in sync
- **Required**: The `--value` property must be set as an inline style on each inner `<span>`, not on the `.countdown` wrapper
- **Recommended**: Use `aria-live="polite"` and `aria-label` on countdown spans for screen reader accessibility
- **Recommended**: Use `--digits:2` on minute and second spans in clock format to maintain consistent width
