---
name: daisyui
description: Guide for using daisyUI component library with Tailwind CSS for building UI components, theming, and responsive design
---

# daisyUI Component Library

Use this skill when building user interfaces with daisyUI and Tailwind CSS, implementing UI components, or configuring themes.

## When to Use This Skill

Activate when:
- Building UI components with daisyUI
- Choosing appropriate daisyUI components for design needs
- Implementing responsive layouts with daisyUI
- Configuring or customizing themes
- Converting designs to daisyUI components
- Troubleshooting daisyUI component styling

## What is daisyUI?

daisyUI is a Tailwind CSS component library providing:

- **Semantic component classes** - High-level abstractions of Tailwind utilities
- **35 built-in themes** - Light, dark, and creative theme variants
- **Framework-agnostic** - Works with any HTML/CSS project
- **Utility-first compatible** - Combine daisyUI components with Tailwind utilities

## Installation

For installation instructions, see the official documentation: https://daisyui.com/docs/install/

## Component Categories

daisyUI provides 60+ components across these categories. Each has a reference file at `references/components/{name}.md`:

### Actions
button, dropdown, modal, swap, theme-controller

### Data Display
accordion, avatar, badge, card, carousel, chat-bubble, collapse, countdown, diff, kbd, progress, radial-progress, stat, table, timeline

### Data Input
checkbox, file-input, input, radio, range, rating, select, textarea, toggle, validator

### Navigation
breadcrumbs, drawer, link, menu, navbar, pagination, steps, tabs

### Layout
divider, dock, fab, footer, hero, indicator, join, mask, stack

### Feedback
alert, loading, skeleton, toast, tooltip

### Mockup Components
mockup-browser, mockup-code, mockup-phone, mockup-window

### Utilities
calendar, fieldset, filter, label, list, status

**For component-specific guidance**, read `references/components/{component}.md` (e.g., `references/components/button.md`).

## Quick Usage

### Button

```html
<button class="btn btn-primary">Primary Button</button>
```

### Card

```html
<div class="card w-96 bg-base-100 shadow-xl">
  <div class="card-body">
    <h2 class="card-title">Card Title</h2>
    <p>Card description text</p>
  </div>
</div>
```

### Modal

```html
<button class="btn" onclick="my_modal.showModal()">Open Modal</button>

<dialog id="my_modal" class="modal">
  <div class="modal-box">
    <h3 class="font-bold text-lg">Modal Title</h3>
    <p class="py-4">Modal content here</p>
    <div class="modal-action">
      <form method="dialog">
        <button class="btn">Close</button>
      </form>
    </div>
  </div>
</dialog>
```

## Theming

daisyUI comes with 35 built-in themes. Configure in CSS:

```css
@import "tailwindcss";
@plugin "daisyui" {
  themes: light --default, dark --prefersdark, cupcake;
}
```

Apply via `data-theme` attribute:

```html
<html data-theme="dark">
  <div data-theme="light">Theme can be nested</div>
</html>
```

### Theme Colors

Semantic color classes that adapt to each theme:

- **Brand**: `primary`, `secondary`, `accent`, `neutral`
- **Base**: `base-100`, `base-200`, `base-300`
- **State**: `info`, `success`, `warning`, `error`
- Add `-content` suffix for contrasting text color

```html
<div class="bg-primary text-primary-content">Themed content</div>
```

**For theme customization and advanced configuration**: See `references/theming.md`

## When to Consult References

### Component Documentation
Each component has its own reference file at `references/components/{component}.md`. All available components:

**Actions**: button, dropdown, modal, swap, theme-controller

**Data Display**: accordion, avatar, badge, card, carousel, chat-bubble, collapse, countdown, diff, kbd, progress, radial-progress, stats, table, timeline

**Data Input**: checkbox, file-input, input, radio, range, rating, select, textarea, toggle, validator

**Navigation**: breadcrumbs, drawer, link, menu, navbar, pagination, steps, tabs

**Layout**: divider, dock, fab, footer, hero, indicator, join, mask, stack

**Feedback**: alert, loading, skeleton, toast, tooltip

**Mockup Components**: mockup-browser, mockup-code, mockup-phone, mockup-window

**Utilities**: calendar, fieldset, filter, label, list, status

### Other References
- **Theming and customization**: Read `references/theming.md`
- **Common patterns**: Read `references/patterns.md`
