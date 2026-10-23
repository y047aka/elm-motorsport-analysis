// Test fixtures for the circuit tools: a circuit config, the Overpass elements
// it is surveyed from, and a geometry file in the served profile. Nothing here
// reads the repository's own surveys — a fixture says what the pipeline's
// checks answer to on their own, and stays square enough to check by hand.

import type { Circuit, OsmMember, OsmNode, OsmRelation, OsmWay, OverpassAnswer } from "../circuit-geometry.ts";

export const testCircuit: Circuit = {
  relation: 999,
  slug: "test_circuit",
  finishRole: "start",
  lapLength: 4000,
  geojson: "app/static/geometry/test_circuit.geojson",
  script: "circuits/tests/fixtures.ts",
  survey: "The Test Circuit",
};

/** A circuit's published sector lengths summing to `testCircuit`'s lap. */
export const stretches = [2000, 1200, 800];

/** A stand-in for a circuit like COTA: a lap of the length the timing feed
 * measures in seconds, and an atlas layer to read against it. */
export const cotaLike: Circuit = {
  relation: 1,
  slug: "cota",
  finishRole: "start",
  lapLength: 5515,
  atlas: { url: "https://example.org/cota.geojson" },
  geojson: "x",
  script: "x",
  survey: "The Circuit of the Americas",
};

export const osmNode = (id: number, lat: number, lon: number): OsmNode => ({ type: "node", id, lat, lon });

export const osmWay = (id: number, nodes: number[], tags: Record<string, string> = {}): OsmWay => ({
  type: "way",
  id,
  nodes,
  tags,
});

export const member = (type: string, role: string, ref: number): OsmMember => ({ type, role, ref });

/** A square lap of ~3.7 km surveyed at 47°N — east, south, west and back —
 * plus a two-point pit lane. The way out of the start is driven one way and
 * the relation names its first node `start`, as a kept relation is tagged; the
 * rest carry no oneway, so the chain is free to turn them. */
export function squareAnswer(): OverpassAnswer {
  const nodes = [
    osmNode(1, 47.0, 0.0),
    osmNode(2, 47.0, 0.01),
    osmNode(3, 46.99, 0.01),
    osmNode(4, 46.99, 0.0),
    osmNode(5, 46.995, -0.002),
  ];
  const ways = [
    osmWay(1, [1, 2], { oneway: "yes" }),
    osmWay(2, [2, 3]),
    osmWay(3, [3, 4]),
    osmWay(4, [4, 1]),
    osmWay(5, [2, 5]),
  ];
  const relation: OsmRelation = {
    type: "relation",
    id: testCircuit.relation,
    members: [member("node", "start", 1), member("way", "", 1), member("way", "", 2), member("way", "", 3), member("way", "", 4), member("way", "pit_lane", 5)],
  };
  return { elements: [relation, ...nodes, ...ways], osm3s: { timestamp_osm_base: "2026-01-01T00:00:00Z" } };
}

/** A geometry file in the served profile: a three-point outline on the same
 * corner of the world the square is surveyed at, ending at the published lap. */
export function geometryFile(outline: Record<string, unknown>, coords: [number, number][]): string {
  return JSON.stringify({
    type: "FeatureCollection",
    features: [
      {
        type: "Feature",
        properties: { role: "outline", circuit: "test_circuit", direction: "clockwise", frame: { origin: { lat: 47.0, lon: -0.002 }, parallel: 46.994 }, ...outline },
        geometry: { type: "LineString", coordinates: coords },
      },
      {
        type: "Feature",
        properties: { role: "pit_lane", circuit: "test_circuit" },
        geometry: { type: "LineString", coordinates: [[0.01, 47.0], [-0.002, 46.995]] },
      },
    ],
  });
}
