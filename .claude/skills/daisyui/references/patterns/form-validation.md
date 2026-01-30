# Form with Validation Feedback

**Components**: input, join, button

Form inputs with validation states.

```html
<form class="space-y-4">
  <!-- Valid input -->
  <fieldset class="fieldset">
    <legend class="fieldset-legend">Email</legend>
    <input type="email" value="valid@email.com" class="input input-success w-full" />
    <p class="fieldset-label text-success">Email is valid</p>
  </fieldset>
  
  <!-- Invalid input -->
  <fieldset class="fieldset">
    <legend class="fieldset-legend">Password</legend>
    <input type="password" class="input input-error w-full" />
    <p class="fieldset-label text-error">Password must be at least 8 characters</p>
  </fieldset>
  
  <!-- Input with icon button -->
  <fieldset class="fieldset">
    <legend class="fieldset-legend">Search</legend>
    <div class="join w-full">
      <input type="text" placeholder="Search..." class="input join-item flex-1" />
      <button class="btn btn-primary join-item">Search</button>
    </div>
  </fieldset>
</form>
```

## Validation States

| State | Input Class | Text Class |
|-------|-------------|------------|
| Success | `input-success` | `text-success` |
| Error | `input-error` | `text-error` |
| Warning | `input-warning` | `text-warning` |

## Usage Notes

- Use `fieldset` + `fieldset-legend` wrapper for consistent spacing and structure (daisyUI v5)
- Apply validation classes dynamically based on input state
- Display helper text using `fieldset-label` or `<p class="label">`
- Use `join` to combine inputs with buttons

## Related Patterns

- [Authentication Page](./authentication.md) - Complete login form
- [Search with Filters](./search-filters.md) - Search input patterns

## Related Components

- [Input](../components/input.md)
- [Join](../components/join.md)
- [Button](../components/button.md)
