# Authentication Page

**Components**: card, input, checkbox, button, divider

Card-based login form combining card + input + checkbox.

```html
<div class="min-h-screen flex items-center justify-center bg-base-200">
  <div class="card w-full max-w-sm bg-base-100 shadow-xl">
    <div class="card-body">
      <h2 class="card-title justify-center text-2xl font-bold">Login</h2>

      <form class="space-y-4 mt-4">
        <fieldset class="fieldset">
          <legend class="fieldset-legend">Email</legend>
          <input type="email" placeholder="email@example.com" class="input w-full" required />
        </fieldset>

        <fieldset class="fieldset">
          <legend class="fieldset-legend">Password</legend>
          <input type="password" placeholder="Enter password" class="input w-full" required />
          <p class="label">
            <a href="#" class="link link-hover">Forgot password?</a>
          </p>
        </fieldset>

        <label class="flex items-center gap-2 cursor-pointer">
          <input type="checkbox" class="checkbox checkbox-sm" />
          <span>Remember me</span>
        </label>

        <button class="btn btn-primary w-full">Login</button>
      </form>

      <div class="divider">OR</div>
      <button class="btn btn-outline w-full">Continue with Google</button>
    </div>
  </div>
</div>
```

## Usage Notes

- Center the card vertically and horizontally with flexbox
- Use `max-w-sm` to constrain width on larger screens
- Add social login options below a divider
- Include "Forgot password?" link for user convenience
- Use `fieldset` + `fieldset-legend` for form structure (daisyUI v5)

## Related Patterns

- [Form with Validation](./form-validation.md) - Input validation states

## Related Components

- [Card](../components/card.md)
- [Input](../components/input.md)
- [Button](../components/button.md)
- [Checkbox](../components/checkbox.md)
