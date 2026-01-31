# daisyUI Configuration

Configure daisyUI in your CSS file.

## Simplest Setup (Recommended Start)

```css
@import "tailwindcss";
@plugin "daisyui";
```

This enables daisyUI with default settings (light + dark themes). Start with this, then add options only if needed.

## Configuration Options

For customization, use `@plugin "daisyui" { ... }`:

| Option | Default | Type | Description |
|--------|---------|------|-------------|
| `themes` | `light --default, dark --prefersdark` | string/list/false/all | Themes to enable |
| `root` | `":root"` | string | Selector for CSS variables |
| `include` | (empty) | comma-separated list | Components to include (whitelist) |
| `exclude` | (empty) | comma-separated list | Components to exclude |
| `prefix` | `""` | string | Prefix for all daisyUI classes |
| `logs` | `true` | boolean | Enable/disable daisyUI logs |

## Examples

### Basic Configuration

```css
@import "tailwindcss";
@plugin "daisyui" {
  themes: light --default, dark --prefersdark, cupcake;
}
```

### Enable All Themes

```css
@plugin "daisyui" {
  themes: all;
}
```

### Disable Themes

```css
@plugin "daisyui" {
  themes: false;
}
```

### Include Only Specific Components

```css
@plugin "daisyui" {
  include: button, card, modal;
}
```

### Exclude Components

```css
@plugin "daisyui" {
  exclude: checkbox, footer, typography;
}
```

### Add Class Prefix

```css
@plugin "daisyui" {
  prefix: d-;
}
```

With prefix, classes become `d-btn`, `d-card`, etc.

### Shadow DOM / Web Components

```css
@plugin "daisyui" {
  root: ":host";
}
```

### Disable Logs

```css
@plugin "daisyui" {
  logs: false;
}
```
