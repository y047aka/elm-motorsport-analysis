<!--
TEMPLATE GUIDE:
This template is for creating high-precision references for the daisyUI skill.
Focus on daisyUI-specific information that Claude Code needs for accurate code generation.

【KEY PRINCIPLES】
- Document ALL class names listed in the official documentation → Provides complete reference
- Use Type column to classify each class (Component, Part, Style, Color, Size, Modifier, Placement, Behavior)
- Do NOT document responsive prefixes (`sm:btn-sm`, etc.) → Standard Tailwind functionality
- Do NOT document simple HTML attributes (disabled, etc.) → Common knowledge

【WHAT TO DOCUMENT】
1. All daisyUI class names with Type classification
2. Required HTML structure (dialog elements, form method="dialog", etc.)
3. Component-specific constraints (e.g., modal-box must be inside modal)
4. Browser API integration (e.g., element.showModal())
5. daisyUI-specific modifiers (btn-wide, btn-square, etc.)

How to use:
1. Replace placeholders like {ComponentName}, {prefix}, etc.
2. List all classes from the official documentation in the Class Reference table
3. Add supplementary notes only when official docs are unclear
4. Keep only necessary sections in Essential Examples
5. Delete all unnecessary sections
-->

# {ComponentName}

{One-line concise description - document daisyUI-specific features}

## Class Reference

| Class name | Type | Description |
|------------|------|-------------|
| `{prefix}` | Component | Base class |
| `{prefix}-{variant}` | Style | {Style description} |
| `{prefix}-neutral` | Color | Neutral color |
| `{prefix}-primary` | Color | Primary color |
| `{prefix}-secondary` | Color | Secondary color |
| `{prefix}-accent` | Color | Accent color |
| `{prefix}-info` | Color | Info color |
| `{prefix}-success` | Color | Success color |
| `{prefix}-warning` | Color | Warning color |
| `{prefix}-error` | Color | Error color |
| `{prefix}-xs` | Size | Extra small |
| `{prefix}-sm` | Size | Small |
| `{prefix}-md` | Size | Medium (default) |
| `{prefix}-lg` | Size | Large |
| `{prefix}-xl` | Size | Extra large |
| `{prefix}-{modifier}` | Modifier | {Modifier description} |
| `{prefix}-{part}` | Part | {Part description - note required parent/child relationships} |
| `{prefix}-{placement}` | Placement | {Placement description} |
| `{prefix}-{behavior}` | Behavior | {Behavior description} |

<!--
【Type classification guidelines】
- Component: Base class that must be applied to the root element (e.g., `btn`, `modal`, `table`)
- Part: Child element classes that must be used inside the Component (e.g., `modal-box`, `card-body`, `stat-title`)
- Style: Visual appearance variants (e.g., `btn-outline`, `btn-ghost`, `btn-link`, `btn-dash`, `btn-soft`)
- Color: Named color variants (neutral, primary, secondary, accent, info, success, warning, error)
- Size: Scale options (xs, sm, md, lg, xl)
- Modifier: Layout or shape adjustments (e.g., `btn-wide`, `btn-block`, `btn-square`, `btn-circle`, `table-zebra`)
- Placement: Position or direction (e.g., `modal-top`, `modal-bottom`, `tooltip-left`)
- Behavior: State or interaction classes (e.g., `btn-active`, `btn-disabled`, `modal-open`)

【Notes column guidelines】
- For Part classes: Note required parent relationships (e.g., "Must be used inside modal")
- For Modifier/Placement/Behavior: Add brief explanation when not self-evident
- For Component/Style/Color/Size: Simple description is sufficient
- Omit Notes column entirely if no classes need supplementary explanation
-->


## Essential Examples

### Basic usage

```html
<!-- Copy-paste ready minimal implementation - required classes and HTML structure only -->
```

### With structure

```html
<!-- Only include when complex HTML structure is required
     e.g., dialog elements for modal, hierarchical structure for dropdown, form method="dialog", etc.

     Delete if structure is simple (like <button class="btn">) -->
```

### Interactive

```html
<!-- Only include when browser API integration is required
     e.g., dialog.showModal(), checkbox:checked pseudo-class, etc.

     Delete if no API integration is needed -->
```

<!--
Section deletion criteria:
- "Basic usage": Required (do not delete)
- "With structure": Delete if structure is simple
- "Interactive": Delete if no browser API integration

Deprecated sections:
- "Colors and styles" → Claude Code already knows color/style patterns
- "States" → Not needed as it's HTML standard
- "Responsive" → Not needed as it's standard Tailwind functionality
- "Icon buttons" → Not needed as it's a common HTML pattern
-->

## Notes

<!--
Documentation criteria:
✅ Required: daisyUI-specific constraints (form tag in modal-action, use of dialog element, etc.)
✅ Recommended: daisyUI-specific accessibility patterns
✅ Deprecated: v4.x breaking changes, old class names
❌ Not needed: General browser behavior, HTML standard knowledge

Delete the entire Notes section if there are no notes to document
-->

- **Required**: {daisyUI-specific constraints}
- **Recommended**: {daisyUI-specific accessibility patterns}
- **Deprecated**: {Information changed in v4.x}
