# daisyUI Utilities

daisyUI-specific utility classes and CSS variables.

## Border Radius

Standardized border radius values:

| Class | CSS Variable | Use Case |
|-------|--------------|----------|
| `rounded-box` | `--radius-box` | Cards, modals (large components) |
| `rounded-field` | `--radius-field` | Buttons, inputs (medium components) |
| `rounded-selector` | `--radius-selector` | Checkboxes, badges (small components) |

```html
<div class="rounded-box bg-base-200 p-4">Card-like element</div>
<button class="rounded-field bg-primary px-4 py-2">Button-like element</button>
<span class="rounded-selector bg-accent px-2">Badge-like element</span>
```

## Glass Effect

```html
<div class="glass p-4">
  Glassmorphism effect
</div>
```

## Size Variables

| CSS Variable | Purpose |
|--------------|---------|
| `--size-selector` | Base scale for small elements |
| `--size-field` | Base scale for medium elements |

## Theme Variables

| CSS Variable | Purpose |
|--------------|---------|
| `--radius-box` | Border radius for large components |
| `--radius-field` | Border radius for medium components |
| `--radius-selector` | Border radius for small components |
| `--border` | Default border width |
| `--depth` | Depth/shadow intensity |
| `--noise` | Noise texture intensity |

## Component-Specific Variables

Components may expose their own CSS variables for customization:

- `--alert-color` - Alert component color
- `--btn-color` - Button component color
- etc.

See individual component documentation for available variables.
