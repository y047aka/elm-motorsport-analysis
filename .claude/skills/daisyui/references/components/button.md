# Button

Buttons allow the user to take actions or make choices.

## Class name table

| Class name | Type | Description |
|------------|------|-------------|
| `btn` | Component | Button |
| `btn-neutral` | Color | neutral color |
| `btn-primary` | Color | primary color |
| `btn-secondary` | Color | secondary color |
| `btn-accent` | Color | accent color |
| `btn-info` | Color | info color |
| `btn-success` | Color | success color |
| `btn-warning` | Color | warning color |
| `btn-error` | Color | error color |
| `btn-outline` | Style | outline style |
| `btn-dash` | Style | dash style |
| `btn-soft` | Style | soft style |
| `btn-ghost` | Style | ghost style |
| `btn-link` | Style | looks like a link |
| `btn-active` | Behavior | looks active |
| `btn-disabled` | Behavior | looks disabled |
| `btn-xs` | Size | Extra small size |
| `btn-sm` | Size | Small size |
| `btn-md` | Size | Medium size (default) |
| `btn-lg` | Size | Large size |
| `btn-xl` | Size | Extra large size |
| `btn-wide` | Modifier | more horizontal padding |
| `btn-block` | Modifier | Full width |
| `btn-square` | Modifier | 1:1 ratio |
| `btn-circle` | Modifier | 1:1 ratio with rounded corners |

## Examples

### Button

```html
<button class="btn">Default</button>
```

### Button sizes

```html
<button class="btn btn-xs">Xsmall</button>
<button class="btn btn-sm">Small</button>
<button class="btn">Medium</button>
<button class="btn btn-lg">Large</button>
<button class="btn btn-xl">Xlarge</button>
```

### Button with color

```html
<button class="btn btn-neutral">Neutral</button>
<button class="btn btn-primary">Primary</button>
<button class="btn btn-secondary">Secondary</button>
<button class="btn btn-accent">Accent</button>
<button class="btn btn-info">Info</button>
<button class="btn btn-success">Success</button>
<button class="btn btn-warning">Warning</button>
<button class="btn btn-error">Error</button>
```

### Button with color + outline style

```html
<button class="btn btn-outline">Default</button>
<button class="btn btn-outline btn-neutral">Neutral</button>
<button class="btn btn-outline btn-primary">Primary</button>
<button class="btn btn-outline btn-secondary">Secondary</button>
<button class="btn btn-outline btn-accent">Accent</button>
<button class="btn btn-outline btn-info">Info</button>
<button class="btn btn-outline btn-success">Success</button>
<button class="btn btn-outline btn-warning">Warning</button>
<button class="btn btn-outline btn-error">Error</button>
```

### Button with color + dash style

```html
<button class="btn btn-dash">Default</button>
<button class="btn btn-dash btn-neutral">Neutral</button>
<button class="btn btn-dash btn-primary">Primary</button>
<button class="btn btn-dash btn-secondary">Secondary</button>
<button class="btn btn-dash btn-accent">Accent</button>
<button class="btn btn-dash btn-info">Info</button>
<button class="btn btn-dash btn-success">Success</button>
<button class="btn btn-dash btn-warning">Warning</button>
<button class="btn btn-dash btn-error">Error</button>
```

### Button with color + soft style

```html
<button class="btn btn-soft">Default</button>
<button class="btn btn-soft btn-neutral">Neutral</button>
<button class="btn btn-soft btn-primary">Primary</button>
<button class="btn btn-soft btn-secondary">Secondary</button>
<button class="btn btn-soft btn-accent">Accent</button>
<button class="btn btn-soft btn-info">Info</button>
<button class="btn btn-soft btn-success">Success</button>
<button class="btn btn-soft btn-warning">Warning</button>
<button class="btn btn-soft btn-error">Error</button>
```

### Button with ghost style

```html
<button class="btn btn-ghost">Default</button>
<button class="btn btn-ghost btn-neutral">Neutral</button>
<button class="btn btn-ghost btn-primary">Primary</button>
<button class="btn btn-ghost btn-secondary">Secondary</button>
<button class="btn btn-ghost btn-accent">Accent</button>
<button class="btn btn-ghost btn-info">Info</button>
<button class="btn btn-ghost btn-success">Success</button>
<button class="btn btn-ghost btn-warning">Warning</button>
<button class="btn btn-ghost btn-error">Error</button>
```

### Button with link style

```html
<button class="btn btn-link">Default</button>
<button class="btn btn-link btn-primary">Primary</button>
```

### Disabled button

```html
<button class="btn" disabled>Disabled</button>
<button class="btn btn-disabled">Disabled using class</button>
```

### Active button

```html
<button class="btn btn-active">Default</button>
<button class="btn btn-active btn-neutral">Neutral</button>
<button class="btn btn-active btn-primary">Primary</button>
<button class="btn btn-active btn-secondary">Secondary</button>
<button class="btn btn-active btn-accent">Accent</button>
<button class="btn btn-active btn-info">Info</button>
<button class="btn btn-active btn-success">Success</button>
<button class="btn btn-active btn-warning">Warning</button>
<button class="btn btn-active btn-error">Error</button>
```

### Button as link

```html
<a role="button" class="btn">Link</a>
<input type="button" value="Button" class="btn" />
<input type="submit" value="Submit" class="btn" />
<form action="" method="POST">
  <input type="reset" value="Reset" class="btn" />
  <input type="radio" name="options" class="btn" aria-label="Radio" />
  <input type="checkbox" class="btn" aria-label="Checkbox" />
</form>
```

### Button shapes

```html
<button class="btn">Normal</button>
<button class="btn btn-wide">Wide button (more horizontal padding)</button>

<!-- 
button + height/width styles
-->
<button class="btn size-20" style="height: 5rem; width: 5rem">100x100px</button>
```

### Icon button

```html
<div>
  <button class="btn">
    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" /></svg>
  </button>
</div>

<div>
  <button class="btn">
    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" /></svg>
    Button
  </button>
</div>
```

### Square button

```html
<button class="btn btn-square">
  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg>
</button>
<button class="btn btn-square btn-soft">
  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg>
</button>
<button class="btn btn-square btn-outline">
  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg>
</button>
```

### Circle button

```html
<button class="btn btn-circle">
  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg>
</button>
<button class="btn btn-circle btn-soft">
  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg>
</button>
<button class="btn btn-circle btn-outline">
  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg>
</button>
```

### Block button

```html
<button class="btn btn-block">block</button>
```

### Loading state

```html
<button class="btn btn-square">
  <span class="loading loading-spinner"></span>
</button>
<button class="btn">
  <span class="loading loading-spinner"></span>
  loading
</button>
```

### State colors

```html
<button class="btn">Button</button>
<button class="btn btn-neutral">Button</button>
<button class="btn btn-primary">Button</button>
<button class="btn btn-secondary">Button</button>
<button class="btn btn-accent">Button</button>
<button class="btn btn-info">Button</button>
<button class="btn btn-success">Button</button>
<button class="btn btn-warning">Button</button>
<button class="btn btn-error">Button</button>
<button class="btn btn-ghost">Button</button>
<button class="btn btn-link">Button</button>
```
