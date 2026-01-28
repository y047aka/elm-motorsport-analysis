# Input

Text input component for user data entry.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `input` | Component | Component for `<input type="text">` tag or a wrapper of `<input type="text">` tag |
| `input-ghost` | Style | Borderless variant |
| `input-neutral` | Color | Neutral color |
| `input-primary` | Color | Primary color |
| `input-secondary` | Color | Secondary color |
| `input-accent` | Color | Accent color |
| `input-info` | Color | Info color |
| `input-success` | Color | Success color |
| `input-warning` | Color | Warning color |
| `input-error` | Color | Error color |
| `input-xs` | Size | Extra small |
| `input-sm` | Size | Small |
| `input-md` | Size | Medium (default) |
| `input-lg` | Size | Large |
| `input-xl` | Size | Extra large |

## Essential Examples

### Basic usage

```html
<input type="text" placeholder="Type here" class="input w-full max-w-xs" />
```

### With structure

```html
<!-- With label and helper text -->
<label class="form-control w-full max-w-xs">
  <div class="label">
    <span class="label-text">What is your name?</span>
  </div>
  <input type="text" placeholder="Type here" class="input w-full max-w-xs" />
  <div class="label">
    <span class="label-text-alt">Helper text</span>
  </div>
</label>
```

### With icon

```html
<!-- Input as wrapper element -->
<label class="input flex items-center gap-2">
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="currentColor" class="h-4 w-4 opacity-70">
    <path d="M8 8a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM12.735 14c.618 0 1.093-.561.872-1.139a6.002 6.002 0 0 0-11.215 0c-.22.578.254 1.139.872 1.139h9.47Z" />
  </svg>
  <input type="text" class="grow" placeholder="Username" />
</label>
```

### Input group

```html
<div class="join">
  <input class="input join-item" placeholder="Email" />
  <button class="btn join-item">Subscribe</button>
</div>
```

### With validation

```html
<!-- Success state -->
<label class="form-control w-full max-w-xs">
  <div class="label">
    <span class="label-text">Email</span>
  </div>
  <input type="email" class="input input-success w-full" value="valid@email.com" />
  <div class="label">
    <span class="label-text-alt text-success">Email is valid</span>
  </div>
</label>

<!-- Error state -->
<label class="form-control w-full max-w-xs">
  <div class="label">
    <span class="label-text">Password</span>
  </div>
  <input type="password" class="input input-error w-full" />
  <div class="label">
    <span class="label-text-alt text-error">Password must be at least 8 characters</span>
  </div>
</label>
```

## Notes

- **Required**: Can be used as wrapper element. Apply `input` class to `<label>` with `flex items-center gap-2` to include icons, badges, or kbd elements
- **Recommended**: Use `<label class="form-control">` wrapper for labels and helper text
- **Recommended**: Supported input types: text, password, email, number, date, datetime-local, week, month, tel, url, search, time, and datalist
