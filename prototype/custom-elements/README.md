# shadcn via Custom Elements prototype

Drives real shadcn components from Elm through custom elements, to find out
what the integration costs before committing to it. Not wired into the app.

Three elements, each answering something different:

- `shadcn-select` — a data-shaped component (Radix `Select`, pinned from the
  `new-york-v4` registry). Takes options, returns a value, has no children.
- `shadcn-button` — a container-shaped one (Base UI `Button`, from the
  `base-nova` registry elm-chadcn derives from), whose content comes from Elm
  through a shadow root and a `<slot>`.
- `ce-probe` — a styling-only stand-in, used twice: twelve in an `Html.Keyed`
  list that can be rotated, to price a reorder, and sixty-two in a list that
  can be mounted and unmounted, to price a mount against plain Elm nodes.

## Run

```console
nix develop --command bash -c 'cd prototype/custom-elements && pnpm vite'
```

The strips at the bottom of the page carry the counters. They are painted by
the page itself because a devtools console evaluates in an isolated world,
where `window.__ceStats` is a different object than the one the elements
mutate — reading the counters any other way gives stale numbers.

## What it establishes

**The round trip works in both directions.** Elm passes `options` as a JSON
property and receives a `value-change` custom event; Radix portals its popup to
`document.body`, and the page's Tailwind reaches the trigger because React
renders into the light DOM rather than a shadow root.

**Elm has to own the state, and one line decides whether it does.** With
`value={this._value ?? undefined}`, clearing the selection from Elm left the
trigger still showing the old label: React reads `undefined` as "uncontrolled"
and Radix then keeps its own selection, so the two states silently diverge.
`?? ""` keeps it controlled. Nothing in the types catches this — the element
renders and the app looks fine until something clears the value.

**Unrelated re-renders are cheap.** Ticking the model ~30 times without
touching the selection left the counters at `react renders 1 | options set 1`:
Elm did not re-assign the properties, so React never re-rendered. A real state
change costs 2 property assignments and 2 React renders. Since the app this is
for redraws every animation frame, that was the main risk, and it does not
materialise.

**A keyed reorder is nearly free, once a move is told apart from a removal.**
Elm does move the DOM node — an instance id rendered inside `ce-probe` travels
with its label — but the lifecycle barely fires and the React root survives.
Twelve elements over six rotations cost one disconnect, one connect, and no
root teardown at all.

Telling a move from a removal is the whole trick: a reorder removes and
re-inserts within one task, so a teardown queued from the removal has to be
cancelled when the node comes back. Unmounting straight from
`disconnectedCallback` instead rebuilds a root on every move, and React then
warns that `createRoot` was called on a container that already had one.

**Elm's children can go inside, through a shadow root and a `<slot>`.** They
stay in the light DOM, so the page's Tailwind reaches them, and Elm updates
them without React re-rendering: pressing the button three times left React at
its single initial render. The button React draws is inside the shadow root, so
the page's rules are adopted into it — built once and shared between instances.

**React never sees a click on slotted content.** Its synthetic `onClick` stayed
at zero across three presses while the native event reached the host every
time: React attaches its listeners inside its own container, and the event's
target is in the light DOM, outside it. Elm listens for the native event on the
host instead.

That last one decides what a custom element is worth for a container component.
For a Button the interactive surface *is* the slotted children, so React's
behaviour layer is bypassed and what remains is the class strings, which do not
need React to produce.

**Mounting costs about ten times as much as a plain Elm node.** Sixty-two
badges, the size the standings list runs at, measured under Playwright:

```
  plain elm        2.8ms   [3, 3, 3, 2, 3, 3, 2]
  custom elements  26.6ms  [25, 26, 27, 14, 28, 27, 27]
```

In absolute terms that is ~24ms extra, a frame and a half, paid once when the
list appears rather than on every frame — a reorder is free and an unrelated
re-render does not reach React at all. It does not rule the approach out; it
prices what a React root per instance costs for a component that only needs
classes, and says where the line falls between components worth wrapping and
components worth writing as plain Elm.

`bench.mjs` runs this. Not in the app's browser pane: that pane throttles
animation frames, Elm applies its patch on one, and the measurement then
reports the wait for a frame rather than the work — 2011ms for a list that was
already complete.

## Costs

React + Base UI + Radix add ~118KB gzipped over an Elm-only build. Irrelevant
for a Tauri app, decisive for a web one.

JSX needs `esbuild: { jsx: "automatic" }` in `vite.config.ts`; without a
`tsconfig.json` esbuild defaults to the classic transform and the element fails
at runtime with `React is not defined` while the rest of the page renders
normally.

## Limits

Memory was not measured. Sixty-two live React roots, plus a shadow root each
where children are taken, is a standing cost this says nothing about.

An earlier version of this prototype reported a reorder destroying a React root
per moved element. That measurement was wrong twice over: it unmounted from
`disconnectedCallback` without checking whether the node was coming back, and
it was read on a page where HMR had been reloading modules and recreating every
element between clicks. Reordering is not a reason to avoid custom elements.
