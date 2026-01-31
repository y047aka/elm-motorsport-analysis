# Footer

Page bottom navigation and information section.

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `footer` | Component | Container for footer content |
| `footer-title` | Part | Section heading styles for footer navigation groups |
| `footer-center` | Placement | Center all footer content |
| `footer-horizontal` | direction | Horizontal layout for footer items |
| `footer-vertical` | direction | Vertical layout (default) |

## Essential Examples

### Basic usage

```html
<footer class="footer bg-neutral text-neutral-content p-10">
  <nav>
    <h6 class="footer-title">Services</h6>
    <a class="link link-hover">Branding</a>
    <a class="link link-hover">Design</a>
    <a class="link link-hover">Marketing</a>
  </nav>
  <nav>
    <h6 class="footer-title">Company</h6>
    <a class="link link-hover">About us</a>
    <a class="link link-hover">Contact</a>
  </nav>
  <nav>
    <h6 class="footer-title">Legal</h6>
    <a class="link link-hover">Terms of use</a>
    <a class="link link-hover">Privacy policy</a>
  </nav>
</footer>
```

### Centered footer

```html
<footer class="footer footer-center bg-base-200 text-base-content p-4">
  <aside>
    <p>Copyright © 2024 - All right reserved by ACME Industries Ltd</p>
  </aside>
</footer>
```

### With social icons

```html
<footer class="footer bg-neutral text-neutral-content items-center p-4">
  <aside class="grid-flow-col items-center">
    <svg width="36" height="36" viewBox="0 0 24 24" class="fill-current">
      <path d="..."></path>
    </svg>
    <p>Copyright © 2024 - All right reserved</p>
  </aside>
  <nav class="grid-flow-col gap-4 md:place-self-center md:justify-self-end">
    <a><svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" class="fill-current"><path d="..."></path></svg></a>
    <a><svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" class="fill-current"><path d="..."></path></svg></a>
  </nav>
</footer>
```

## Notes

- **Recommended**: Use `<nav>` elements for link groups with `footer-title` headings
- **Recommended**: Combine with background colors like `bg-neutral`, `bg-base-200` and matching text colors
- **Changed since v5**: Vertical layout is now default, use `footer-horizontal` for horizontal layout
