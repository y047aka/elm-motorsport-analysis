# Mockup Code

Terminal-style code block mockup with line prefix indicators.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `mockup-code` | Component | Terminal code block container |

## Essential Examples

### Basic usage

```html
<div class="mockup-code w-full">
  <pre data-prefix="$"><code>npm i daisyui</code></pre>
</div>
```

### With structure

```html
<!-- Multi-line output with prefixes and status colors -->
<div class="mockup-code w-full">
  <pre data-prefix="$"><code>npm i daisyui</code></pre>
  <pre data-prefix=">" class="text-warning"><code>installing...</code></pre>
  <pre data-prefix=">" class="text-success"><code>Done!</code></pre>
</div>
```

## Notes

- **Required**: Each line must be a `<pre>` containing a `<code>` element
- **Required**: Use `data-prefix` attribute on `<pre>` to show line prefixes (e.g., `$`, `>`, `1`, `~`)
- **Recommended**: Omit `data-prefix` entirely on a `<pre>` to show no prefix for that line
- **Recommended**: Use Tailwind text color classes on individual `<pre>` elements for status coloring (e.g., `text-warning`, `text-success`)
- **Recommended**: Use `bg-{color} text-{color}-content` on the root to theme the entire code block
- **Recommended**: Override container colors with theme classes (e.g., `bg-primary text-primary-content`) for custom terminal themes
