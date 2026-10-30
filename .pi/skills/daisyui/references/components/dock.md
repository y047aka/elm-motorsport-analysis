# Dock

Bottom navigation bar that sticks to the bottom of the screen for quick access to primary actions.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `dock` | Component | Container for the bottom navigation bar |
| `dock-label` | Part | Text label for an individual dock item |
| `dock-active` | Modifier | Applies active state styling to a dock item |
| `dock-xs` | Size | Extra small |
| `dock-sm` | Size | Small |
| `dock-md` | Size | Medium (default) |
| `dock-lg` | Size | Large |
| `dock-xl` | Size | Extra large |

## Essential Examples

### Basic usage

```html
<div class="dock">
  <button>
    <svg class="size-[1.2em]" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.25 12l8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25" />
    </svg>
    <span class="dock-label">Home</span>
  </button>

  <button class="dock-active">
    <svg class="size-[1.2em]" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21.75 6.75v10.5a2.25 2.25 0 01-2.25 2.25h-15a2.25 2.25 0 01-2.25-2.25v-10.5a2.25 2.25 0 012.25-2.25h15a2.25 2.25 0 012.25 2.25z" />
    </svg>
    <span class="dock-label">Inbox</span>
  </button>

  <button>
    <svg class="size-[1.2em]" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.75 6a3.75 3.75 0 11-7.5 0 3.75 3.75 0 017.5 0zM4.501 20.118a7.5 7.5 0 0114.998 0A17.933 17.933 0 0112 21.75c-2.676 0-5.216-.584-7.499-1.632z" />
    </svg>
    <span class="dock-label">Profile</span>
  </button>
</div>
```

## Notes

- **Required**: Dock sticks to the bottom of the screen by default
- **Recommended**: For iOS devices, include `<meta name="viewport" content="viewport-fit=cover">` to avoid content being hidden behind the home indicator
- **Recommended**: Use `dock-active` on exactly one item to indicate the current page
