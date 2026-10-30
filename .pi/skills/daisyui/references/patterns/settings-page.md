# Settings Page

**Components**: card, toggle, select, divider

User settings panel with grouped options.

```html
<div class="card bg-base-100 shadow-xl max-w-2xl mx-auto">
  <div class="card-body">
    <h2 class="card-title text-2xl">Settings</h2>
    
    <!-- Notifications Section -->
    <div class="py-4">
      <h3 class="font-semibold mb-4">Notifications</h3>
      <div class="space-y-4">
        <label class="flex items-center justify-between cursor-pointer">
          <span>Email notifications</span>
          <input type="checkbox" class="toggle toggle-primary" checked />
        </label>
        <label class="flex items-center justify-between cursor-pointer">
          <span>Push notifications</span>
          <input type="checkbox" class="toggle toggle-primary" />
        </label>
        <label class="flex items-center justify-between cursor-pointer">
          <span>Weekly digest</span>
          <input type="checkbox" class="toggle toggle-primary" checked />
        </label>
      </div>
    </div>

    <div class="divider"></div>

    <!-- Preferences Section -->
    <div class="py-4">
      <h3 class="font-semibold mb-4">Preferences</h3>
      <div class="space-y-4">
        <fieldset class="fieldset">
          <legend class="fieldset-legend">Language</legend>
          <select class="select w-full">
            <option>English</option>
            <option>Japanese</option>
            <option>Spanish</option>
          </select>
        </fieldset>
        <fieldset class="fieldset">
          <legend class="fieldset-legend">Timezone</legend>
          <select class="select w-full">
            <option>UTC</option>
            <option>Asia/Tokyo</option>
            <option>America/New_York</option>
          </select>
        </fieldset>
      </div>
    </div>

    <div class="card-actions justify-end mt-4">
      <button class="btn btn-ghost">Cancel</button>
      <button class="btn btn-primary">Save Changes</button>
    </div>
  </div>
</div>
```

## Usage Notes

- Group related settings with section headers
- Use dividers to separate distinct sections
- Toggle switches work well for on/off preferences
- Select dropdowns for multiple choice options
- Always include Cancel and Save actions
- Use `fieldset` + `fieldset-legend` for form structure (daisyUI v5)

## Related Patterns

- [Dashboard Layout](./dashboard.md) - Main layout structure
- [User Profile Card](./user-profile.md) - User information display

## Related Components

- [Card](../components/card.md)
- [Toggle](../components/toggle.md)
- [Select](../components/select.md)
- [Divider](../components/divider.md)
