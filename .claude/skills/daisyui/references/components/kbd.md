# Kbd

Styled keyboard key representation for displaying shortcuts and key labels.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `kbd` | Component | Base class for keyboard key styling |
| `kbd-xs` | Size | Extra small |
| `kbd-sm` | Size | Small |
| `kbd-md` | Size | Medium (default) |
| `kbd-lg` | Size | Large |
| `kbd-xl` | Size | Extra large |

## Essential Examples

### Basic usage

```html
<kbd class="kbd">K</kbd>
```

### With structure

```html
<!-- Key combination -->
<kbd class="kbd">ctrl</kbd>
+
<kbd class="kbd">shift</kbd>
+
<kbd class="kbd">del</kbd>

<!-- Inline with text -->
Press <kbd class="kbd kbd-sm">F</kbd> to pay respects.
```
