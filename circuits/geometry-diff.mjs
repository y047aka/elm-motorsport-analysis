// Lays any two geometries of this repository's profile against each other and
// says, in metres, where they disagree — optionally as an SVG overlay, which is
// the same reading at one glance instead of three numbers.
//
//     node circuits/geometry-diff.mjs <a.geojson> <b.geojson> [--every <m>] [--svg <out.svg>]
//
// The only claim a file must keep is the one the profile makes of its outline:
// a line with metres measured from its own lap's zero. The basis is free — this
// is the reading that compares a survey to a measurement, or a survey to the
// same survey a year later — and the report quotes each file's own `basis` and
// `source` beside every figure, so an output can never be read as two files
// agreeing when only one line was kept.
//
// Distances are ground distances on one equirectangular projection of the two
// lines together; each line's own metres travel with its points, so a line
// stretched to a published lap length and a line measured at its own are still
// compared place against place, which is the comparison that says what a basis
// change would cost.

import { readFile, writeFile } from "node:fs/promises";
import { resolve, basename } from "node:path";

import { isEntry, projection } from "./circuit-geometry.mjs";

const width = 1000;

async function run(lines, args) {
  const { project } = projection(lines.flatMap((line) => line.coords.map(earth)));
  const points = lines.map((line) => line.coords.map(earth).map(project));
  for (const [at, line] of lines.entries()) {
    console.log(
      `${line.name}: basis ${line.props.basis ?? "?"}, ${line.metres[line.metres.length - 1].toFixed(1)} m` +
        (line.props.source ? ` — ${line.props.source}` : ""),
    );
  }
  for (const [from, to] of [
    [0, 1],
    [1, 0],
  ]) {
    const apart = apartness(points[from], lines[from].metres, points[to], lines[to].metres, args.every);
    console.log(
      `sampled every ${args.every} m along ${lines[from].name} (${apart.count}): mean apart ${apart.mean.toFixed(1)} m, ` +
        `max ${apart.worst.distance.toFixed(1)} m at ${apart.worst.aMetres.toFixed(0)} m, our-side ${apart.worst.bMetres.toFixed(1)} m`,
    );
  }
  if (args.svg !== null) {
    await writeFile(args.svg, svgOverlay(lines, points));
    console.log(`overlay: ${args.svg}`);
  }
}

function readArgs(argv) {
  const args = { paths: [], every: 25, svg: null };
  for (let at = 0; at < argv.length; at++) {
    if (argv[at] === "--every") args.every = Number(argv[++at]);
    else if (argv[at] === "--svg") args.svg = argv[++at];
    else args.paths.push(resolve(argv[at]));
  }
  if (args.paths.length !== 2) fail("usage: node circuits/geometry-diff.mjs <a.geojson> <b.geojson> [--every <m>] [--svg <out.svg>]");
  if (!Number.isFinite(args.every) || args.every <= 0) fail(`"${args.every}" is not a distance`);
  return args;
}

const earth = ([lon, lat]) => ({ lat, lon });

/** The outline of one geometry file: its coordinates, its own metres, and the
 * properties a report quotes so the reader knows what two lines were compared. */
export function outlineOf(text, name) {
  const outline = JSON.parse(text).features.find((f) => f.properties?.role === "outline");
  if (!outline) throw new Error(`${name}: no outline feature`);
  const { metres, ...props } = outline.properties;
  if (outline.geometry.coordinates.length !== metres.length) {
    throw new Error(`${name}: ${metres.length} metres for ${outline.geometry.coordinates.length} points`);
  }
  return { name: name ?? outline.properties.circuit, props, coords: outline.geometry.coordinates, metres };
}

/** The first line laid against the second, sampled every `every` metres along
 * the first: the nearest ground distance to the second and where that place
 * falls on each line's own measure. */
export function apartness(aPoints, aMetres, bPoints, bMetres, every) {
  const length = aMetres[aMetres.length - 1];
  const samples = [];
  for (let s = 0; s < length; s += every) {
    const near = nearestOn(interpolate(aPoints, aMetres, s), bPoints, bMetres);
    samples.push({ aMetres: s, bMetres: near.metres, distance: near.distance });
  }
  const worst = samples.reduce((a, b) => (b.distance > a.distance ? b : a));
  const mean = samples.reduce((sum, x) => sum + x.distance, 0) / samples.length;
  return { count: samples.length, mean, worst };
}

export function interpolate(points, metres, s) {
  let i = 1;
  while (i < metres.length - 1 && metres[i] < s) i++;
  const span = metres[i] - metres[i - 1];
  const at = span === 0 ? 0 : (s - metres[i - 1]) / span;
  return {
    x: points[i - 1].x + (points[i].x - points[i - 1].x) * at,
    y: points[i - 1].y + (points[i].y - points[i - 1].y) * at,
  };
}

export function nearestOn(point, points, metres) {
  let best = { distance: Infinity, metres: 0 };
  for (let i = 1; i < points.length; i++) {
    const near = toSegment(point, points[i - 1], points[i]);
    if (near.distance < best.distance) {
      best = { distance: near.distance, metres: metres[i - 1] + (metres[i] - metres[i - 1]) * near.at };
    }
  }
  return best;
}

function toSegment(p, a, b) {
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const span = dx * dx + dy * dy;
  const at = span === 0 ? 0 : Math.max(0, Math.min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / span));
  return { distance: Math.hypot(p.x - (a.x + dx * at), p.y - (a.y + dy * at)), at };
}

// The overlay is a reading aid, not a drawing: two strokes of one projection,
// and the provenance each file carries as its own comment, so a saved overlay
// says what it was comparing long after the files moved.
function svgOverlay(lines, points) {
  const at = { x: Math.min(...points.flat().map((p) => p.x)), y: Math.min(...points.flat().map((p) => p.y)) };
  const span = {
    x: Math.max(...points.flat().map((p) => p.x)) - at.x,
    y: Math.max(...points.flat().map((p) => p.y)) - at.y,
  };
  const scale = (width - 40) / Math.max(span.x, span.y);
  const place = (p) => `${(20 + (p.x - at.x) * scale).toFixed(1)},${(20 + (at.y + span.y - p.y) * scale).toFixed(1)}`;
  const colours = ["#d43a3a", "#2a6df4"];
  const paths = lines
    .map((line, at) => `  <path d="M ${points[at].map(place).join(" L ")}" fill="none" stroke="${colours[at]}" stroke-width="2" opacity="0.8"/>`)
    .join("\n");
  const provenance = lines.map((line) => `  <!-- ${line.name}: ${line.props.basis ?? "?"} — ${line.props.source ?? "no source"} -->`).join("\n");
  const height = 40 + span.y * scale;
  return `<?xml version="1.0" encoding="UTF-8"?>
<!-- Geometry overlay: ${lines[0].name} in red against ${lines[1].name} in blue.
${lines.map((l) => l.props.license ? `Data: ${l.name} is © under ${l.props.license}.` : "").filter(Boolean).join("\n")} -->
${provenance}
<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height.toFixed(0)}" viewBox="0 0 ${width} ${height.toFixed(0)}">
  <rect width="100%" height="100%" fill="white"/>
${paths}
</svg>
`;
}

function fail(message) {
  console.error(message);
  process.exit(1);
}

if (isEntry(import.meta.url)) {
  const args = readArgs(process.argv.slice(2));
  try {
    const lines = [];
    for (const path of args.paths) lines.push(outlineOf(await readFile(path, "utf8"), basename(path, ".geojson")));
    await run(lines, args);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
