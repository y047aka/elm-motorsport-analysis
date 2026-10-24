// Lays any two geometries of this repository's profile against each other and
// says, in metres, where they disagree — optionally as an SVG overlay, which is
// the same reading at one glance instead of three numbers.
//
//     node circuits/geometry-diff.ts <a.geojson> <b.geojson> [--every <m>] [--svg <out.svg>]
//
// The only claim a file must keep is the one the profile makes of its outline:
// a line with metres measured from its own lap's zero. The basis is free — this
// is the reading that compares a survey to a measurement, or a survey to the
// same survey a year later — and the report quotes each file's own `basis` and
// `source` beside every figure, so an output can never be read as two files
// agreeing when only one line was kept.
//
// The comparison itself — the projection, the sampling, the nearness — is
// `apartness.ts`, which the atlas command reads too. Its own claim to keep is the
// one the profile makes of a file: a line with metres measured from its own lap's
// zero.

import { readFile, writeFile } from "node:fs/promises";
import { resolve, basename } from "node:path";

import type { GeometryFile, Point } from "./circuit-geometry.ts";
import { isEntry, onEarth, projection, reason } from "./circuit-geometry.ts";
import type { KeptLine } from "./geometry-file.ts";
import { outlineOf } from "./geometry-file.ts";
import { apartness } from "./apartness.ts";

const width = 1000;

async function run(lines: KeptLine[], args: { paths: string[]; every: number; svg: string | null }): Promise<void> {
  const { project } = projection(lines.flatMap((line) => line.coords.map(onEarth)));
  const points = lines.map((line) => line.coords.map(onEarth).map(project));
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

export function readArgs(argv: string[]): { paths: string[]; every: number; svg: string | null } {
  const args: { paths: string[]; every: number; svg: string | null } = { paths: [], every: 25, svg: null };
  for (let at = 0; at < argv.length; at++) {
    if (argv[at] === "--every") args.every = Number(argv[++at]);
    else if (argv[at] === "--svg") args.svg = argv[++at];
    else args.paths.push(resolve(argv[at]));
  }
  if (args.paths.length !== 2) fail("usage: node circuits/geometry-diff.ts <a.geojson> <b.geojson> [--every <m>] [--svg <out.svg>]");
  if (!Number.isFinite(args.every) || args.every <= 0) fail(`"${args.every}" is not a distance`);
  return args;
}

// The overlay is a reading aid, not a drawing: two strokes of one projection,
// and the provenance each file carries as its own comment, so a saved overlay
// says what it was comparing long after the files moved.
export function svgOverlay(lines: KeptLine[], points: Point[][]): string {
  const at = { x: Math.min(...points.flat().map((p) => p.x)), y: Math.min(...points.flat().map((p) => p.y)) };
  const span = {
    x: Math.max(...points.flat().map((p) => p.x)) - at.x,
    y: Math.max(...points.flat().map((p) => p.y)) - at.y,
  };
  const scale = (width - 40) / Math.max(span.x, span.y);
  const place = (p: Point) => `${(20 + (p.x - at.x) * scale).toFixed(1)},${(20 + (at.y + span.y - p.y) * scale).toFixed(1)}`;
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

function fail(message: string): never {
  throw new Error(message);
}

if (isEntry(import.meta.url)) {
  try {
    const args = readArgs(process.argv.slice(2));
    const lines: KeptLine[] = [];
    for (const path of args.paths) {
      lines.push(outlineOf(JSON.parse(await readFile(path, "utf8")) as GeometryFile, basename(path, ".geojson")));
    }
    await run(lines, args);
  } catch (error) {
    console.error(reason(error));
    process.exitCode = 1;
  }
}
