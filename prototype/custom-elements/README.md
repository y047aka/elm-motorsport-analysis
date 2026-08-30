# shadcn via Custom Elements prototype

Drives real shadcn components from Elm through custom elements, to find out
what the integration costs before committing to it. Not wired into the app.

The elements, each answering something different:

- `shadcn-button` — a container-shaped one (Base UI `Button`, from the
  `base-nova` registry the app went on to use), whose content comes from Elm
  through a shadow root and a `<slot>`.
- `ce-probe` — a styling-only stand-in, used twice: twelve in an `Html.Keyed`
  list that can be rotated, to price a reorder, and sixty-two in a list that
  can be mounted and unmounted, to price a mount against plain Elm nodes.
- `card-slotted`, `card-named-slots`, `card-plain-*` — three ways of putting
  Elm's content inside shadcn's Card, drawn side by side from the same
  children. Card is the case where the component's own CSS reads the tree its
  content sits in.

## Run

```console
nix develop --command bash -c 'cd prototype/custom-elements && pnpm vite'
```

The strips at the bottom of the page carry the counters. They are painted by
the page itself because a devtools console evaluates in an isolated world,
where `window.__probeStats` is a different object than the one the elements
mutate — reading the counters any other way gives stale numbers.

## What it establishes

**The round trip works in both directions.** Elm passes state as JSON
properties and gets a custom event back, and the page's Tailwind reaches what
React drew, because React renders into the light DOM rather than a shadow root.

**Elm has to own the state, and one line decides whether it does.** Passing a
property through as `undefined` reads to React as "leave this uncontrolled",
and the component then keeps a value of its own beside the one Elm holds: Elm
clears the value, the component goes on showing the old one, and neither side
is wrong about its own copy. Nothing in the types catches it. The element
renders, the app looks right, and it stays right until something clears a value
— which is why the app's wrappers always pass one.

**Unrelated re-renders are cheap.** Twenty-five ticks of the model, touching
nothing the elements read, left `probe: react renders 12` and `button: react
renders 1` — exactly their mounts. Elm does not re-assign a property whose
value has not changed, so React is never asked. Since the app this is for
redraws every animation frame, that was the main risk, and it does not
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

## Putting Elm's content inside a Card

Card carries no behaviour at all — seven `<div>`s typed `React.ComponentProps<"div">` —
but its classes read what it contains:

```
has-data-[slot=card-footer]:pb-0     drop the bottom padding when a footer is inside
has-[>img:first-child]:pt-0          drop the top padding when an image leads
*:[img:first-child]:rounded-t-xl     round that image's top corners
```

`:has()`, `group-*` and `*:` all match within one tree, and slotted content is
not in the tree of the shadow root it is projected into. Three arrangements,
with the footer and the leading image both switched on:

```
                     padding-bottom   padding-top   img radius
A2  Elm's parts slotted into a
    React-rendered Card                     16px         16px         0px
A1  React renders every part,
    Elm fills named slots                    0px         16px         0px
B   elements apply the vendored
    classes to themselves                    0px          0px        14px
```

**A2 is the naive reading of the goal and none of the three rules fire.** React
draws the Card into a shadow root and Elm's header, content and footer arrive
through a `<slot>`; the `data-slot="card-footer"` is right there on screen and
Card cannot see it.

**A1 recovers whatever React renders and nothing else.** With every part drawn
by React inside the shadow root, the footer is in Card's own tree and the
padding collapses. The image is still Elm's, still slotted, so the two rules
about a leading image stay dark.

**B is the only one where Card behaves as upstream wrote it**, because there is
only one tree. Each element sets the vendored class string and `data-slot` on
itself and Elm renders the structure and its content as ordinary children. No
React root and no shadow root, so the mount costs what a plain Elm node costs.

What B needs in exchange:

- Card's class strings have to be reachable. They are literals inside
  `cn(...)` in the component bodies, not a `cva` export like `buttonVariants`,
  so `ui/card.tsx` hoists them into an exported `cardClasses` — the marked
  deviation `shadcn add --diff` will report.
- A custom element is `display: inline` where the divs upstream renders are
  blocks. The fallback goes in `@layer base` so the display utilities inside
  those same class strings still win.

The criterion this leaves is not the one the Button measurement gave. There the
question was whether React does any work. Here it is **whether the component's
own CSS reads the tree its content lives in** — if it does, the content has to
share that tree, and only B puts it there.

## Costs

React and Base UI took the app's bundle from 45.68KB gzipped to 136.03KB,
about three times. Irrelevant for a Tauri app, decisive for a web one.

JSX needs either a `tsconfig.json` saying `"jsx": "react-jsx"` or an
`esbuild: { jsx: "automatic" }` in `vite.config.ts`, which is what this
prototype has. With neither, esbuild defaults to the classic transform and the
element fails at runtime with `React is not defined` while the rest of the page
renders normally.

## Limits

Memory was not measured. Sixty-two live React roots, plus a shadow root each
where children are taken, is a standing cost this says nothing about.

An earlier version of this prototype reported a reorder destroying a React root
per moved element. That measurement was wrong twice over: it unmounted from
`disconnectedCallback` without checking whether the node was coming back, and
it was read on a page where HMR had been reloading modules and recreating every
element between clicks. Reordering is not a reason to avoid custom elements.
