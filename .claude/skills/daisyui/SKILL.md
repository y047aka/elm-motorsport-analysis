---
name: daisyui
description: Guide for using daisyUI component library with Tailwind CSS for building UI components, theming, and responsive design
---

# daisyUI Component Library (v5.x)

Use this skill when building user interfaces with daisyUI and Tailwind CSS.

**Current version: daisyUI v5.x** (requires Tailwind CSS v4.x)

## When to Use This Skill

- Building UI components with daisyUI
- Choosing appropriate components for design needs
- Configuring or customizing themes
- Troubleshooting daisyUI styling

## Decision Flow

| Building... | Reference |
|-------------|-----------|
| Forms (inputs, selects, checkboxes) | `references/forms.md` |
| Navigation (navbar, menu, tabs) | `references/navigation.md` |
| Feedback (alerts, toasts, loading) | `references/feedback.md` |
| Layout (cards, modals, hero) | `references/layout.md` |
| Data display (tables, stats, badges) | `references/data-display.md` |
| Complete UI patterns | `references/patterns.md` |
| Theme configuration | `references/theming.md` |
| Specific component details | `references/components/{name}.md` |

## Color System

Semantic colors that adapt to each theme:

| Type | Classes |
|------|---------|
| Brand | `primary`, `secondary`, `accent`, `neutral` |
| Base | `base-100`, `base-200`, `base-300` |
| State | `info`, `success`, `warning`, `error` |

Add `-content` suffix for contrasting text: `bg-primary text-primary-content`

## Size System

Most components support sizes:

```
{component}-xs    Extra small
{component}-sm    Small
{component}-md    Medium (default)
{component}-lg    Large
{component}-xl    Extra large
```

## Quick Theme Setup

```css
@import "tailwindcss";
@plugin "daisyui" {
  themes: light --default, dark --prefersdark;
}
```

```html
<html data-theme="dark">
  <div data-theme="light">Theme can be nested</div>
</html>
```

For advanced theming: `references/theming.md`

## Installation

See: https://daisyui.com/docs/install/
