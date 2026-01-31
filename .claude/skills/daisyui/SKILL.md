---
name: daisyui
description: |
  Guide for daisyUI v5 component library with Tailwind CSS v4. 
  
  **Auto-trigger on:**
  - Component names: "button", "card", "modal", "table", "tabs", "badge", "alert", "navbar", "form"
  - Actions: "UI implementation", "daisyUI"
  - Styling: "theme setup", "dark mode", "responsive design", "component styling"
  
  **IMPORTANT:** Always read this skill when implementing or modifying UI components to ensure correct v5 syntax and avoid deprecated patterns from v4.
---

# daisyUI Component Library (v5.x)

Use this skill when building user interfaces with daisyUI and Tailwind CSS.

**Current version: daisyUI v5.x** (requires Tailwind CSS v4.x)

> **Claude's knowledge cutoff warning**: daisyUI v5 has breaking changes from v4. Always reference this skill for correct syntax rather than relying on prior knowledge.

## When to Use This Skill

- Building UI components with daisyUI
- Choosing appropriate components for design needs
- Configuring or customizing themes
- Troubleshooting daisyUI styling

## Quick Start: Installation & Setup

### Step 1: Install daisyUI

```bash
npm install -D daisyui
```

### Step 2: Configure CSS (Simplest Form)

```css
@import "tailwindcss";
@plugin "daisyui";
```

This is the **minimal and most reliable** configuration. Use this first, then add options only if needed.

### Step 3: Optional Theme Configuration

For theme customization, see `references/config.md`:

```css
@import "tailwindcss";
@plugin "daisyui" {
  themes: light --default, dark --prefersdark;
}
```

### Step 4: Apply Theme in HTML

```html
<html data-theme="dark">
  <div data-theme="light">Theme can be nested</div>
</html>
```

## Join Component (Grouping Elements)

When using `join` for grouped elements, add `join-item` to each child:

```html
<div class="join">
  <button class="btn join-item">-</button>
  <span class="badge join-item">5</span>
  <button class="btn join-item">+</button>
</div>
```

## Vite Integration Note

If styles aren't applying with Vite, build CSS separately with Tailwind CLI:

```json
{
  "scripts": {
    "css:build": "npx @tailwindcss/cli -i style.css -o public/style.css --minify",
    "dev": "npm run css:build && vite",
    "build": "npm run css:build && vite build"
  }
}
```

## Component Reference

### By Category

**Actions**: button, dropdown, modal, swap, theme-controller
**Data Input**: input, textarea, select, checkbox, radio, toggle, range, rating, file-input, calendar, label, fieldset, validator
**Data Display**: table, stats, card, badge, avatar, countdown, diff, kbd, list, timeline, hover-3d, hover-gallery, text-rotate
**Navigation**: navbar, menu, tabs, breadcrumbs, pagination, steps, dock, link
**Feedback**: alert, toast, loading, progress, radial-progress, skeleton, status
**Layout**: drawer, hero, footer, divider, join, indicator, stack, fab, mask, collapse, accordion, carousel

### Direct Access

- Single component: `references/components/{name}.md`
- UI pattern: `references/patterns/{name}.md`
- Theming: `references/theming.md`
- Colors: `references/colors.md`
- Configuration: `references/config.md`
- Utilities: `references/utilities.md`

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

## v4 → v5 Breaking Changes

**CRITICAL**: These patterns from v4 are deprecated in v5:

| v4 (Deprecated) | v5 (Current) |
|-----------------|--------------|
| `btn-group` | `join` with `join-item` on children |
| `input-bordered` | `input` (bordered by default) |
| `input-group` | `join` with `join-item` |
| `card-bordered` | `card-border` |
| `card-compact` | `card-sm` |
| `btm-nav` | `dock` |
| `tab-lifted` | `tabs-lift` (on parent) |
| `tab-bordered` | `tabs-border` (on parent) |
| `tab-boxed` | `tabs-box` (on parent) |

## Troubleshooting

### Styles not applying
1. Verify daisyUI is installed: `@plugin "daisyui"` in CSS
2. Check class spelling (e.g., `btn-primary` not `button-primary`)
3. Ensure Tailwind CSS v4.x is used (daisyUI v5 requires it)
4. **For Vite**: Build CSS with Tailwind CLI separately (see Vite Integration Note)

### Theme not changing
- Verify `data-theme` attribute on `<html>` or container element
- Check theme is enabled in CSS config

### Classes work in CLI but not in build
- Vite may not process `@plugin` correctly
- Solution: Use Tailwind CLI to pre-build CSS to `public/` directory

## Installation

See: https://daisyui.com/docs/install/
