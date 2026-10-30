# Confirmation Modal

**Components**: modal, button

Destructive action confirmation dialog.

```html
<button class="btn btn-error" onclick="confirm_modal.showModal()">Delete Item</button>

<dialog id="confirm_modal" class="modal modal-bottom sm:modal-middle">
  <div class="modal-box">
    <h3 class="text-lg font-bold">Confirm Deletion</h3>
    <p class="py-4">Are you sure you want to delete this item? This action cannot be undone.</p>
    <div class="modal-action">
      <form method="dialog">
        <button class="btn btn-ghost">Cancel</button>
      </form>
      <button class="btn btn-error" onclick="deleteItem(); confirm_modal.close();">Delete</button>
    </div>
  </div>
  <form method="dialog" class="modal-backdrop">
    <button>close</button>
  </form>
</dialog>
```

## Modal Variants

```html
<!-- Bottom sheet on mobile, centered on desktop -->
<dialog class="modal modal-bottom sm:modal-middle">...</dialog>

<!-- Always centered -->
<dialog class="modal modal-middle">...</dialog>

<!-- Always bottom -->
<dialog class="modal modal-bottom">...</dialog>
```

## JavaScript API

```javascript
// Open modal
document.getElementById('confirm_modal').showModal();

// Close modal
document.getElementById('confirm_modal').close();
```

## Usage Notes

- Use `modal-bottom sm:modal-middle` for responsive behavior
- Include `modal-backdrop` form for click-outside-to-close
- Use `btn-error` for destructive actions
- Always provide a Cancel option
- Use `method="dialog"` on forms to close modal on submit

## Related Patterns

- [Toast Notifications](./toast-notifications.md) - Non-blocking feedback

## Related Components

- [Modal](../components/modal.md)
- [Button](../components/button.md)
