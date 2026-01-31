---
name: daisyui
description: Guide for daisyUI v5 component library with Tailwind CSS v4. Use when building UI components, configuring themes, or creating responsive designs. Triggers on: "daisyUI", "button component", "card", "modal", "form", "dashboard layout", "navigation menu", "theme setup", "alert", "table", "tabs".
---

# daisyUI Component Library (v5.x)

Use this skill when building user interfaces with daisyUI and Tailwind CSS.

**Current version: daisyUI v5.x** (requires Tailwind CSS v4.x)

## When to Use This Skill

- Building UI components with daisyUI
- Choosing appropriate components for design needs
- Configuring or customizing themes
- Troubleshooting daisyUI styling

## Workflow: Building a UI Component

### Step 1: Identify Component Type
Determine from the Component Reference which component(s) suit the need.

### Step 2: Check Component Documentation
Navigate to `references/components/{name}.md` for class reference and examples.

### Step 3: Apply Theming (if needed)
Refer to `references/theming.md` for color customization.

### Step 4: Combine into Pattern (if applicable)
Check `references/patterns/` for pre-built layout patterns.

## Component Reference

### By Category

**Actions**: button, dropdown, modal, swap, theme-controller
**Data Input**: input, textarea, select, checkbox, radio, toggle, range, rating, file-input, calendar, label, fieldset, validator
**Data Display**: table, stats, card, badge, avatar, countdown, diff, kbd, list, timeline
**Navigation**: navbar, menu, tabs, breadcrumbs, pagination, steps, dock, link
**Feedback**: alert, toast, loading, progress, radial-progress, skeleton, status
**Layout**: drawer, hero, footer, divider, join, indicator, stack, fab, mask, collapse, accordion, carousel

### Direct Access

- Single component: `references/components/{name}.md`
- UI pattern: `references/patterns/{name}.md`
- Theming: `references/theming.md`

### Common Patterns

| Pattern | Use Case |
|---------|----------|
| dashboard | Stats + card layout |
| authentication | Login/signup forms |
| data-table | Table with actions and pagination |
| settings-page | Toggle and select preferences |
| sidebar-navigation | Drawer with menu |

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

## Troubleshooting

### Styles not applying
- Verify daisyUI is installed: `@plugin "daisyui"` in CSS
- Check class spelling (e.g., `btn-primary` not `button-primary`)
- Ensure Tailwind CSS v4.x is used (daisyUI v5 requires it)

### Theme not changing
- Verify `data-theme` attribute on `<html>` or container element
- Check theme is enabled in CSS config

## Installation

See: https://daisyui.com/docs/install/
