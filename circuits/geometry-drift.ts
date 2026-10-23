// How one geometry file's data answers to another's, feature by feature and
// property by property: the reading the regeneration fence judges, stated
// without opening either file. `regenerate-geometry.ts` runs the pipeline and
// prints what this finds; `--write` is where the writer's layout lands.
//
// The comparison is of parsed data, not bytes: what the fence answers for is
// the drawing, and the writer's layout is allowed to change between the file
// and this reading. `surveyed_at` is the one property exempt — it stamps which
// answer a file was written from rather than what the drawing is made of, and
// it is the one property a live regeneration must move while every degree
// stands still.

import type { GeometryFile } from "./circuit-geometry.ts";

export function driftOf(fresh: GeometryFile, kept: GeometryFile): string[] {
  const drift: string[] = [];
  const roles = [...new Set([...(fresh.features ?? []), ...(kept.features ?? [])].map((f) => f.properties?.role))];
  for (const role of roles) {
    const a = fresh.features?.find((f) => f.properties?.role === role);
    const b = kept.features?.find((f) => f.properties?.role === role);
    if (!a || !b) {
      drift.push(`${role}: only ${a ? "the regeneration" : "the kept file"} holds it`);
      continue;
    }
    if (JSON.stringify(a.geometry) !== JSON.stringify(b.geometry)) {
      drift.push(
        `${role}: the line's points differ at point ${firstDiff(a.geometry?.coordinates ?? [], b.geometry?.coordinates ?? [])}`,
      );
    }
    const aProps = a.properties ?? {};
    const bProps = b.properties ?? {};
    for (const key of new Set([...Object.keys(aProps), ...Object.keys(bProps)])) {
      if (key === "surveyed_at") continue;
      if (JSON.stringify(aProps[key]) !== JSON.stringify(bProps[key])) {
        drift.push(`${role}: ${key} is ${shown(bProps[key])} in the file, ${shown(aProps[key])} from the answer`);
      }
    }
  }
  return drift;
}

export function firstDiff(a: unknown[], b: unknown[]): number {
  for (let at = 0; at < Math.max(a.length, b.length); at++) {
    if (JSON.stringify(a[at]) !== JSON.stringify(b[at])) return at;
  }
  return -1;
}

const shown = (value: unknown) => (value === undefined ? "absent" : JSON.stringify(value));
