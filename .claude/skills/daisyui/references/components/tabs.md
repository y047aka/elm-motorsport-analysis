# Tabs

Tab navigation for switching between views.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `tabs` | Component | Container for tab items |
| `tab` | Part | Individual tab button |
| `tab-content` | Part | Content section following a tab |
| `tabs-box` | Style | Box styling |
| `tabs-border` | Style | Bottom border styling |
| `tabs-lift` | Style | Lift effect styling |
| `tab-active` | Modifier | Active state |
| `tab-disabled` | Modifier | Disabled state |
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

### With content (radio inputs)

```html
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

- With content: Use radio inputs + `tab-content` for built-in toggle behavior
- Alternative: Manage active state via JavaScript with `tab-active` class
