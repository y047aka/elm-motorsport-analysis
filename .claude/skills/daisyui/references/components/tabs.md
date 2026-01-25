# Tabs

Tab navigation component for switching between views.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `tabs` | Component | Container of multiple tab items |
| `tab` | Part | A single tab button (can be button, link, div, radio input, etc) |
| `tab-content` | Part | Tab content that comes immediately after a tab |
| `tabs-box` | Style | Box styling for tabs |
| `tabs-border` | Style | Bottom border styling |
| `tabs-lift` | Style | Lift effect styling |
| `tab-active` | Modifier | Makes a single tab look active |
| `tab-disabled` | Modifier | Makes a single tab look disabled |
| `tabs-top` | Placement | Puts tab buttons on top of the tab-content (default) |
| `tabs-bottom` | Placement | Puts tabs under the tab-content |
| `tabs-xs` | Size | Extra small |
| `tabs-sm` | Size | Small |
| `tabs-md` | Size | Medium size (default) |
| `tabs-lg` | Size | Large |
| `tabs-xl` | Size | Extra large |

## Key Examples

### Basic tabs

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

### Tab sizes

```html
<div role="tablist" class="tabs tabs-border tabs-xs">
  <a role="tab" class="tab">Tiny</a>
  <a role="tab" class="tab tab-active">Tiny</a>
</div>

<div role="tablist" class="tabs tabs-border tabs-sm">
  <a role="tab" class="tab">Small</a>
  <a role="tab" class="tab tab-active">Small</a>
</div>

<div role="tablist" class="tabs tabs-border tabs-lg">
  <a role="tab" class="tab">Large</a>
  <a role="tab" class="tab tab-active">Large</a>
</div>

<div role="tablist" class="tabs tabs-border tabs-xl">
  <a role="tab" class="tab">Extra Large</a>
  <a role="tab" class="tab tab-active">Extra Large</a>
</div>
```

### Tabs with content (radio inputs)

```html
<div role="tablist" class="tabs tabs-lift">
  <input type="radio" name="my_tabs_1" role="tab" class="tab" aria-label="Tab 1" />
  <div role="tabpanel" class="tab-content bg-base-100 border-base-300 rounded-box p-6">
    Tab content 1
  </div>

  <input type="radio" name="my_tabs_1" role="tab" class="tab" aria-label="Tab 2" checked />
  <div role="tabpanel" class="tab-content bg-base-100 border-base-300 rounded-box p-6">
    Tab content 2
  </div>

  <input type="radio" name="my_tabs_1" role="tab" class="tab" aria-label="Tab 3" />
  <div role="tabpanel" class="tab-content bg-base-100 border-base-300 rounded-box p-6">
    Tab content 3
  </div>
</div>
```

### Tab placement

```html
<!-- Tabs on bottom -->
<div role="tablist" class="tabs tabs-bottom tabs-border">
  <a role="tab" class="tab">Tab 1</a>
  <a role="tab" class="tab tab-active">Tab 2</a>
  <a role="tab" class="tab">Tab 3</a>
</div>
```

### Disabled tab

```html
<div role="tablist" class="tabs tabs-border">
  <a role="tab" class="tab">Tab 1</a>
  <a role="tab" class="tab tab-active">Tab 2</a>
  <a role="tab" class="tab tab-disabled">Disabled</a>
</div>
```

### Tabs with icons

```html
<div role="tablist" class="tabs tabs-border">
  <a role="tab" class="tab">
    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
    </svg>
    Home
  </a>
  <a role="tab" class="tab tab-active">
    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
    Details
  </a>
</div>
```
