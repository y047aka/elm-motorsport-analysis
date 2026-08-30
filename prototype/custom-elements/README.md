# shadcn via Custom Elements prototype

What a React component behind a custom element costs, measured rather than
estimated. Not wired into the app.

One element is left, `ce-probe`: a styling-only stand-in for a Badge, extending
the app's own `ReactElement`, so what is measured is the lifecycle the app
ships. It appears twice on the page — twelve in an `Html.Keyed` list that can
be rotated, to price a reorder, and sixty-two in a list that can be mounted and
unmounted, to price a mount against plain Elm nodes.

## Run

```console
nix develop --command bash -c 'cd prototype/custom-elements && pnpm vite'
```

The strips at the bottom of the page carry the counters. They are painted by
the page itself because a devtools console evaluates in an isolated world,
where `window.__probeStats` is a different object than the one the elements
mutate — reading the counters any other way gives stale numbers.

## What it establishes

**Unrelated re-renders are cheap.** Twenty-five ticks of the model, touching
nothing the elements read, left `react renders` exactly where the reorder had
put it. Elm does not re-assign a property whose value has not changed, so React
is never asked. Since the app this is for redraws every animation frame, that
was the main risk, and it does not materialise.

**A keyed reorder is nearly free, once a move is told apart from a removal.**
Elm does move the DOM node — an instance id rendered inside `ce-probe` travels
with its label — and the React root survives the trip. Twelve elements over six
rotations:

```
  connects 12 → 18    disconnects 0 → 6    react mounts 12 → 12
```

Six moves, six disconnect/connect pairs, and not one React tree rebuilt.
`react mounts` counts a `useEffect(…, [])` inside the probe, which fires again
only if the root was torn down and a new one mounted the component afresh.

Telling a move from a removal is the whole trick: a reorder removes and
re-inserts within one task, so a teardown queued from the removal has to be
cancelled when the node comes back. `ReactElement` does that with its `leaving`
flag. Unmounting straight from `disconnectedCallback` instead rebuilds a root on
every move, and React then warns that `createRoot` was called on a container
that already had one.

**Mounting costs about ten times as much as a plain Elm node.** Sixty-two
badges, the size the standings list runs at, measured under Playwright:

```
  plain elm         2.2ms   [2, 2, 2, 2, 2, 3, 3]
  custom elements  25.8ms   [18, 27, 26, 27, 26, 26, 27]
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

## What it established, with the elements now gone

Two questions are closed: the app made its choice, the arrangements it did not
take were deleted, and a second copy of a vendored component beside the app's
had already drifted from it within a day.

### Elm's content inside a shadcn container

Measured with `shadcn-button`, which rendered the app's own `ui/button.tsx`
into a shadow root and put a `<slot>` where the label goes.

It works, in both directions. Elm passes state as JSON properties and gets a
custom event back; Elm's children stay in the light DOM, so the page's Tailwind
reaches them, and Elm updates them without React re-rendering — pressing the
button three times left React at its single initial render. The button React
draws is inside the shadow root, so the page's rules are adopted into it, built
once and shared between instances.

**But React never sees a click on slotted content.** Its synthetic `onClick`
stayed at zero across three presses while the native event reached the host
every time: React attaches its listeners inside its own container, and the
event's target is in the light DOM, outside it.

That decides what a custom element is worth for a container component. For a
Button the interactive surface *is* the slotted children, so React's behaviour
layer is bypassed and what remains is the class strings, which do not need
React to produce. `UI.Button` takes its label as a property instead.

**Elm has to own the state, and one line decides whether it does.** Passing a
property through as `undefined` reads to React as "leave this uncontrolled",
and the component then keeps a value of its own beside the one Elm holds: Elm
clears the value, the component goes on showing the old one, and neither side
is wrong about its own copy. Nothing in the types catches it. The element
renders, the app looks right, and it stays right until something clears a value
— which is why the app's wrappers always pass one.

### Elm's content inside a Card

Measured with three elements that are no longer here: the arrangement it chose
ships as `card-elements.ts`.

Card carries no behaviour at all — seven `<div>`s typed `React.ComponentProps<"div">` —
but its classes read what it contains:

```
has-data-[slot=card-footer]:pb-0     drop the bottom padding when a footer is inside
has-[>img:first-child]:pt-0          drop the top padding when an image leads
*:[img:first-child]:rounded-t-xl     round that image's top corners
```

`:has()`, `group-*` and `*:` all match within one tree, and slotted content is
not in the tree of the shadow root it is projected into. Three arrangements:

```
                     padding-bottom   padding-top   img radius
A2  Elm's parts slotted into a
    React-rendered Card                     16px         16px         0px
A1  React renders every part,
    Elm fills named slots                    0px         16px         0px
B   elements apply the vendored
    classes to themselves                    0px          0px        14px
```

with the footer and the leading image both switched on.

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

Memory was not measured. Sixty-two live React roots are a standing cost this
says nothing about.

An earlier version of this prototype reported a reorder destroying a React root
per moved element. That measurement was wrong twice over: it unmounted from
`disconnectedCallback` without checking whether the node was coming back, and
it was read on a page where HMR had been reloading modules and recreating every
element between clicks. Reordering is not a reason to avoid custom elements.
