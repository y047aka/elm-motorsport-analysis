---
name: shadcn
description: "Work the vendored shadcn components: adding or updating one with the CLI, keeping the drift discipline, crossing the Elm↔element property boundary, deciding whether to mount React, and knowing what each costs. Use when changing anything under app/src/shadcn/ or app/src/UI/Shadcn/, when running `shadcn add`, when a component renders a stale value, a wrong click, or an unexpected per-frame re-render, and before adding Tailwind classes to an Elm wrapper."
---

# The shadcn components

The vendored components, the custom elements in front of them, and the Elm
wrappers behind — `AGENTS.md`'s architecture section maps where they sit and
the no-Tailwind-classes rule; this carries what touching them obliges.

## Adding or updating one

`components.json` configures the CLI, so `shadcn add <name>` writes these
files and `shadcn add <name> --diff` reports how far one has drifted from
upstream. That holds only while the `@/*` alias resolves the same way in
`tsconfig.json` and in `vite.config.ts` — the CLI writes `@/shadcn/...`
imports, and neither file alone makes them build.

Anything this app adds to a vendored component carries a
`Not in upstream base-nova:` comment. `--diff` should report those lines and
nothing else: a line it reports without one is drift to fold back in, since
`add` overwrites the file.

A single class the registry has no variant for does not need to be added
there at all — `cn` puts it last, so the element can pass it and win, which is
how a circular button gets `rounded-full`. A class the registry has no variant
for goes on through `cn`, which is also what drops a base class a variant
contradicts.

## The property boundary

Every prop is set as a JS property, so what crosses the boundary is JSON and
Elm holds the state. Four things that boundary will not carry, all found by
running it rather than by building it:

- A property that arrives as `undefined` reads to React as "leave this
  uncontrolled", and the component then keeps a value beside the one Elm
  holds. Elm clears the value, the component goes on showing the old one, and
  nothing fails — so an element always passes a value, never a hole.
- React's synthetic events never reach a custom element's slotted children, so
  a component Elm passes children to cannot report its own clicks. No element
  takes children at all: the ones that mount nothing render their own node,
  and children Elm rendered would land beside it rather than inside it.
- A `Html.Keyed` reorder removes and re-inserts a node within one task, so a
  teardown queued by `disconnectedCallback` has to be cancelled when the node
  comes back, or every reorder destroys a React root. `ReactElement` guards
  that with its `leaving` flag, and nothing exercises the guard: no element of
  this kind sits in a keyed list today.
- A directory whose name differs from an Elm one only in case is folded into
  it on macOS and only fails on Linux CI. The React sources are laid out as
  the registry expects, so `src/shadcn/` and `src/shadcn/ui/` are both taken:
  the Elm side is `UI.Shadcn.*`, and no top-level Elm module may be named
  `Shadcn` or `Ui`. `src/elements/` takes `Elements` the same way.

An unrelated re-render costs nothing only where the property is a primitive.
Elm compares a property against the last one by reference, so a re-encoded
list or record arrives as a write however little it has changed, and a view
that runs every animation frame then renders React every animation frame.
Measured on the event page: the two elements taking an `items` array rendered
on 181 of 181 frames of playback, showing nothing new. `changed` in
`react-element.ts` is what an object-valued setter compares with — a new
object-valued prop needs it, or a frame you did not change re-renders React.

## What mounts React, and what does not

Two of the elements mount React: the slider and the toggle-group, which are
the two that borrow behaviour — a drag, and a row that answers the arrow keys.
The rest are class strings, and the registry hands those out without React:
`badgeVariants` and `buttonVariants` are both exported, so the badge and
button elements build their own DOM from them with nothing vendored changed.

`card-elements.ts` has a second reason to mount nothing. Card's classes read
the tree its content sits in — `has-data-[slot=card-footer]`,
`has-[>img:first-child]` — and content projected through a `<slot>` is not in
the shadow root's tree, so the element carries the vendored class string and
Elm fills it directly. Nothing may pass one of those a `class`: the element
owns that attribute, and layout belongs on a wrapper around it.

What enforces this boundary is `/app/tests/custom-elements.spec.ts`;
`AGENTS.md`'s Testing section says what it reads and when it fails.

## What one costs, measured

Mounting sixty-two of them takes ~26ms against ~2ms for the same number of
plain Elm nodes, about ten times, paid once when the list appears. A reorder
costs nothing. Ten times a node it only lends class strings to is the reason
nothing mounts React for class strings alone.
