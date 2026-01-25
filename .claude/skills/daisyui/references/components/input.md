# Input

Text input component for user data entry.

## Class Reference

| Class | Description |
|-------|-------------|
| `input` | Base input class |
| `input-bordered` | Adds border |
| `input-ghost` | No border, transparent |
| `input-primary` | Primary color focus |
| `input-secondary` | Secondary color focus |
| `input-accent` | Accent color focus |
| `input-info` | Info state color |
| `input-success` | Success state color |
| `input-warning` | Warning state color |
| `input-error` | Error state color |
| `input-xs` | Extra small size |
| `input-sm` | Small size |
| `input-md` | Medium size (default) |
| `input-lg` | Large size |

## Key Examples

### Basic input

```html
<input type="text" placeholder="Type here" class="input input-bordered w-full max-w-xs" />
```

### Color variants

```html
<input type="text" class="input input-bordered input-primary" placeholder="Primary" />
<input type="text" class="input input-bordered input-secondary" placeholder="Secondary" />
<input type="text" class="input input-bordered input-success" placeholder="Success" />
<input type="text" class="input input-bordered input-error" placeholder="Error" />
```

### Sizes

```html
<input type="text" class="input input-bordered input-xs" placeholder="Extra small" />
<input type="text" class="input input-bordered input-sm" placeholder="Small" />
<input type="text" class="input input-bordered input-md" placeholder="Medium" />
<input type="text" class="input input-bordered input-lg" placeholder="Large" />
```

### With label (form-control)

```html
<label class="form-control w-full max-w-xs">
  <div class="label">
    <span class="label-text">What is your name?</span>
  </div>
  <input type="text" placeholder="Type here" class="input input-bordered w-full max-w-xs" />
  <div class="label">
    <span class="label-text-alt">Helper text</span>
  </div>
</label>
```

### With icon

```html
<label class="input input-bordered flex items-center gap-2">
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="currentColor" class="h-4 w-4 opacity-70">
    <path d="M8 8a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM12.735 14c.618 0 1.093-.561.872-1.139a6.002 6.002 0 0 0-11.215 0c-.22.578.254 1.139.872 1.139h9.47Z" />
  </svg>
  <input type="text" class="grow" placeholder="Username" />
</label>

<label class="input input-bordered flex items-center gap-2">
  <input type="text" class="grow" placeholder="Search" />
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="currentColor" class="h-4 w-4 opacity-70">
    <path fill-rule="evenodd" d="M9.965 11.026a5 5 0 1 1 1.06-1.06l2.755 2.754a.75.75 0 1 1-1.06 1.06l-2.755-2.754ZM10.5 7a3.5 3.5 0 1 1-7 0 3.5 3.5 0 0 1 7 0Z" clip-rule="evenodd" />
  </svg>
</label>
```

### Input group (join)

```html
<div class="join">
  <input class="input input-bordered join-item" placeholder="Email" />
  <button class="btn join-item">Subscribe</button>
</div>
```
