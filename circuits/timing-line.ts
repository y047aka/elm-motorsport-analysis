// The line the lap is measured from, and the question the survey asks of a
// candidate for it: does this place stand where the circuit says its line
// stands? A relation answers with a node, and a run that answered the wrong
// line shifts every distance by the distance between the two lines while still
// looking like a lap. `circuit-geometry.ts` asks the question of a relation's
// node; `circuits/src/Track.flix` asks the same question of a measured line's
// start at a wider allowance, and says why there.

import type { Place } from "./circuit-geometry.ts";
import { apart } from "./circuit-geometry.ts";

/** Where a circuit publishes the line the lap is measured from, and the
 * distance its own map is taken to be worth: `within` narrows how far a
 * candidate may stand from the published place and still be the line. */
export type PublishedLine = Place & { within?: number };

/** How far a relation's node may stand from the published line and still be
 * it: a relation tags the line itself, so the distance allowed is the map's
 * own crosshair. */
export const nodeWithin = 10;

/** The candidate's distance from the published line, judged: a circuit that
 * publishes no line asks nothing, and is answered with nought. A candidate
 * further than the line's own `within`, or than `within` where the line names
 * no distance of its own, fails naming the candidate, its distance, and what
 * `elsewhere` says a reader could have chosen instead. */
export function checkStandsAt(
  subject: string,
  candidate: Place,
  line: PublishedLine | undefined,
  within: number,
  elsewhere: (line: PublishedLine) => string,
): number {
  if (!line) return 0;
  const distance = apart(candidate, line);
  const limit = line.within ?? within;
  if (distance > limit) {
    throw new Error(
      `${subject} is ${distance.toFixed(1)} m from the published timing line, which is not within ${limit} m. ${elsewhere(line)}`,
    );
  }
  return distance;
}

