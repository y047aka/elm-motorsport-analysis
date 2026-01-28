# Tabs

Tab navigation for switching between views.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `tabs` | Component | Container for tab items |
| `tab` | Part | Individual tab button (must be inside tabs container) |
| `tab-content` | Part | Content section following a tab (used with radio input pattern) |
| `tabs-box` | Style | Box styling variant |
| `tabs-border` | Style | Bottom border styling variant |
| `tabs-lift` | Style | Lift effect styling variant |
| `tab-active` | Modifier | Active state for tab |
| `tab-disabled` | Modifier | Disabled state for tab |
| `tabs-top` | Placement | Puts tab buttons on top of the tab-content (default) |
| `tabs-bottom` | Placement | Puts tabs under the tab-content |
| `tabs-xs` | Size | Extra small |
| `tabs-sm` | Size | Small |
| `tabs-md` | Size | Medium (default) |
| `tabs-lg` | Size | Large |
| `tabs-xl` | Size | Extra large |

## Essential Examples

### Basic usage

```html
<div role="tablist" class="tabs">
  <a role="tab" class="tab">Tab 1</a>
  <a role="tab" class="tab tab-active">Tab 2</a>
  <a role="tab" class="tab">Tab 3</a>
</div>
```

### Tab styles

```html
<!-- Border tabs -->
<div role="tablist" class="tabs tabs-border">
  <a role="tab" class="tab">Tab 1</a>
  <a role="tab" class="tab tab-active">Tab 2</a>
  <a role="tab" class="tab">Tab 3</a>
</div>

<!-- Lift tabs -->
<div role="tablist" class="tabs tabs-lift">
  <a role="tab" class="tab">Tab 1</a>
  <a role="tab" class="tab tab-active">Tab 2</a>
  <a role="tab" class="tab">Tab 3</a>
</div>

<!-- Box tabs -->
<div role="tablist" class="tabs tabs-box">
  <a role="tab" class="tab">Tab 1</a>
  <a role="tab" class="tab tab-active">Tab 2</a>
  <a role="tab" class="tab">Tab 3</a>
</div>
```

### Interactive

```html
<!-- With content using radio inputs -->
<div role="tablist" class="tabs tabs-lift">
  <input type="radio" name="my_tabs" role="tab" class="tab" aria-label="Tab 1" />
  <div role="tabpanel" class="tab-content bg-base-100 border-base-300 rounded-box p-6">
    Tab content 1
  </div>

  <input type="radio" name="my_tabs" role="tab" class="tab" aria-label="Tab 2" checked />
  <div role="tabpanel" class="tab-content bg-base-100 border-base-300 rounded-box p-6">
    Tab content 2
  </div>

  <input type="radio" name="my_tabs" role="tab" class="tab" aria-label="Tab 3" />
  <div role="tabpanel" class="tab-content bg-base-100 border-base-300 rounded-box p-6">
    Tab content 3
  </div>
</div>
```

## Notes

- **Required**: For built-in content toggle, use radio inputs with `tab-content` pattern
- **Recommended**: Manage active state via JavaScript with `tab-active` class for custom implementations
- **Recommended**: Use `role="tablist"`, `role="tab"`, and `role="tabpanel"` for accessibility
