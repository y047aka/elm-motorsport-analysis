# Status

Compact indicator dot for communicating element state such as online, offline, or error.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `status` | Component | Base status indicator dot |
| `status-neutral` | Color | Neutral color |
| `status-primary` | Color | Primary color |
| `status-secondary` | Color | Secondary color |
| `status-accent` | Color | Accent color |
| `status-info` | Color | Info color |
| `status-success` | Color | Success color |
| `status-warning` | Color | Warning color |
| `status-error` | Color | Error color |
| `status-xs` | Size | Extra small |
| `status-sm` | Size | Small |
| `status-md` | Size | Medium (default) |
| `status-lg` | Size | Large |
| `status-xl` | Size | Extra large |

## Essential Examples

### Basic usage

```html
<span class="status status-success"></span>
<span class="status status-warning"></span>
<span class="status status-error"></span>
```

### With pulsing animation

```html
<span class="status status-success animate-ping"></span>
```

### Inline with text

```html
<div class="flex items-center gap-2">
  <span class="status status-success"></span>
  <span>Online</span>
</div>
```

## Notes

- **Recommended**: Combine with `animate-ping` for a pulsing notification effect, or `animate-bounce` for attention-drawing indicators
