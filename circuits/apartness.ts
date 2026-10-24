// Laying one line against another: how far a place stands from a line measured in
// metres of its own lap, and the apartness of two such lines. The atlas command runs
// on these readings, and so does the diff — which is why they are a module of their own
// rather than the diff's arithmetic.
//
// The sphere is the one every drawing in this repository is measured on: the one
// `Motorsport.Circuit.Geodesy` projects through, the one the survey is measured with and
// the one the probe counts its laps on. `circuits/geometry/src/Apart.flix` is the same
// four readings in the language the commands a person runs are written in, and
// `app/tests/circuits-geometry-reading.spec.ts` reads the two sources and fails them
// apart over the bound of the sampling loop, which stretch a tie falls on, how a
// zero-length stretch is walked through, and the sphere both are laid on. Two readings
// of one comparison, agreeing by a test rather than by a compiler, is the state this
// repository is in while the pipeline is TypeScript and the diff is Flix; it is not the
// state to keep.
//
// Distances are ground distances on one equirectangular projection of the two lines
// together; each line's own metres travel with its points, so a line stretched to a
// published lap length and a line measured at its own are still compared place against
// place, which is the comparison that says what a basis change would cost.

import type { Point } from "./circuit-geometry.ts";

/** One sampling of a line against another: where on each line's own measure
 * the nearest place stands, and how far apart they are. */
export type Sample = { aMetres: number; bMetres: number; distance: number };

export type Apartness = { count: number; mean: number; worst: Sample };

/** The first line laid against the second, sampled every `every` metres along
 * the first: the nearest ground distance to the second and where that place
 * falls on each line's own measure. */
export function apartness(
  aPoints: Point[],
  aMetres: number[],
  bPoints: Point[],
  bMetres: number[],
  every: number,
): Apartness {
  const length = aMetres[aMetres.length - 1] ?? 0;
  if (length <= 0) {
    fail(`nothing is measured along the sampled line: its own metres end at ${length} m`);
  }
  const samples = [];
  for (let s = 0; s < length; s += every) {
    const near = nearestOn(interpolate(aPoints, aMetres, s), bPoints, bMetres);
    samples.push({ aMetres: s, bMetres: near.metres, distance: near.distance });
  }
  const worst = samples.reduce((a, b) => (b.distance > a.distance ? b : a));
  const mean = samples.reduce((sum, x) => sum + x.distance, 0) / samples.length;
  return { count: samples.length, mean, worst };
}

export function interpolate(points: Point[], metres: number[], s: number): Point {
  let i = 1;
  while (i < metres.length - 1 && metres[i] < s) i++;
  const span = metres[i] - metres[i - 1];
  const at = span === 0 ? 0 : (s - metres[i - 1]) / span;
  return {
    x: points[i - 1].x + (points[i].x - points[i - 1].x) * at,
    y: points[i - 1].y + (points[i].y - points[i - 1].y) * at,
  };
}

/** The nearest place on a line, and the metre of the lap it stands at — between
 * the metres of the stretch it was found on rather than at that stretch's start,
 * because a report quotes a place and not the resolution the file was written at.
 * Of two stretches equally near, the first is the one kept. */
export function nearestOn(point: Point, points: Point[], metres: number[]): { metres: number; distance: number } {
  let best = { distance: Infinity, metres: 0 };
  for (let i = 1; i < points.length; i++) {
    const near = toSegment(point, points[i - 1], points[i]);
    if (near.distance < best.distance) {
      best = { distance: near.distance, metres: metres[i - 1] + (metres[i] - metres[i - 1]) * near.at };
    }
  }
  return best;
}

/** A place onto a stretch: how far from it, and how far along the stretch the
 * nearest place to it stands. A stretch of nought length is a place rather than a
 * stretch, and the nearest place on it is its own start. */
export function toSegment(p: Point, a: Point, b: Point): { distance: number; at: number } {
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const span = dx * dx + dy * dy;
  const at = span === 0 ? 0 : Math.max(0, Math.min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / span));
  return { distance: Math.hypot(p.x - (a.x + dx * at), p.y - (a.y + dy * at)), at };
}

function fail(message: string): never {
  throw new Error(message);
}
