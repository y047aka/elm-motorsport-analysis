# Form Components

Guide for building forms with daisyUI. For specific component details, see individual files in `components/`.

## Quick Reference

| Component | Use Case | Base Class |
|-----------|----------|------------|
| [input](components/input.md) | Text, email, password, number input | `input` |
| [textarea](components/textarea.md) | Multi-line text | `textarea` |
| [select](components/select.md) | Dropdown selection | `select` |
| [checkbox](components/checkbox.md) | Multiple selections, boolean | `checkbox` |
| [radio](components/radio.md) | Single selection from group | `radio` |
| [toggle](components/toggle.md) | On/off switch | `toggle` |
| [range](components/range.md) | Slider value selection | `range` |
| [rating](components/rating.md) | Star rating | `rating` |
| [file-input](components/file-input.md) | File upload | `file-input` |
| [calendar](components/calendar.md) | Date picker | `cally`, `pika-single`, `react-day-picker` |
| [label](components/label.md) | Input prefix/suffix, floating label | `label`, `floating-label` |
| [fieldset](components/fieldset.md) | Group related fields | `fieldset` |
| [validator](components/validator.md) | HTML5 validation feedback | `validator` |

## Shared Patterns

### Color Classes

All form components support semantic colors:

```
{component}-neutral
{component}-primary
{component}-secondary
{component}-accent
{component}-info
{component}-success
{component}-warning
{component}-error
```

### Size Classes

All form components support sizes:

```
{component}-xs    Extra small
{component}-sm    Small
{component}-md    Medium (default)
{component}-lg    Large
{component}-xl    Extra large
```

### Style Classes

Text inputs (`input`, `textarea`, `select`, `file-input`) support:

```
{component}-ghost    Borderless variant
```

**Note**: `{component}-bordered` is deprecated in v4. Border is now default.

## Form Structure

### Basic Field with Label

Use `form-control` wrapper for labels and helper text:

```html
<label class="form-control w-full max-w-xs">
  <div class="label">
    <span class="label-text">Label</span>
  </div>
  <input type="text" class="input" placeholder="Type here" />
  <div class="label">
    <span class="label-text-alt">Helper text</span>
  </div>
</label>
```

### Checkbox/Radio/Toggle with Label

Use `label` with `cursor-pointer`:

```html
<label class="label cursor-pointer">
  <span class="label-text">Label text</span>
  <input type="checkbox" class="checkbox" />
</label>
```

For left-aligned input:

```html
<label class="label cursor-pointer justify-start gap-2">
  <input type="checkbox" class="checkbox" />
  <span class="label-text">Label text</span>
</label>
```

### Fieldset for Grouped Fields

```html
<fieldset class="fieldset bg-base-200 border border-base-300 rounded-box p-4">
  <legend class="fieldset-legend">Account Details</legend>
  
  <label class="label">Email</label>
  <input type="email" class="input" />
  
  <label class="label">Password</label>
  <input type="password" class="input" />
  
  <p class="label">Helper text for the group</p>
</fieldset>
```

### Input with Icon

Apply `input` class to `<label>` as wrapper:

```html
<label class="input flex items-center gap-2">
  <svg class="h-4 w-4 opacity-70"><!-- icon --></svg>
  <input type="text" class="grow" placeholder="Search" />
</label>
```

### Input with Prefix/Suffix Label

```html
<label class="input flex items-center gap-2">
  <span class="label">https://</span>
  <input type="text" class="grow" placeholder="domain" />
  <span class="label">.com</span>
</label>
```

### Floating Label

```html
<label class="floating-label">
  <span>Email</span>
  <input type="email" class="input" placeholder="you@example.com" />
</label>
```

### Input Group with Button

Use `join` component:

```html
<div class="join">
  <input class="input join-item" placeholder="Email" />
  <button class="btn join-item">Subscribe</button>
</div>
```

## Validation

### Manual Validation States

Apply color classes directly:

```html
<input type="email" class="input input-success" value="valid@email.com" />
<input type="password" class="input input-error" />
```

### Auto Validation with validator

Uses native HTML5 validation:

```html
<fieldset>
  <input class="input validator" type="email" required />
  <div class="validator-hint">Enter a valid email</div>
</fieldset>
```

**Important**: Wrap each field in a container (e.g., `<fieldset>`) to isolate hint visibility.

Supported attributes: `required`, `minlength`, `maxlength`, `pattern`, `min`, `max`, `type`

## Component Selection Guide

| Need | Use |
|------|-----|
| Single line text | `input` |
| Multi-line text | `textarea` |
| Select from list | `select` |
| Yes/No, multiple options | `checkbox` |
| One of many options | `radio` |
| On/Off setting | `toggle` |
| Numeric range | `range` |
| Star rating | `rating` |
| File upload | `file-input` |
| Date picker | `calendar` (with library) or `<input type="date">` |

## Related Patterns

- [Authentication Page](patterns.md#authentication-page) - Login form example
- [Form with Validation Feedback](patterns.md#form-with-validation-feedback) - Validation states
