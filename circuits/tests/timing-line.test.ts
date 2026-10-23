// The one question both pipelines ask of a place on the earth: does it stand
// where the circuit says its line stands. The two allowances are the decision
// under test — what a relation's node is held to, and what the start of a
// measured line is — beside the published line's own narrowing of either.

import assert from "node:assert/strict";
import { test } from "node:test";

import { checkOrigin, checkStandsAt, measuredWithin, nodeWithin } from "../timing-line.ts";

test("checkStandsAt answers nought for a circuit that publishes no line", () => {
  assert.equal(checkStandsAt("role=start", { lat: 0, lon: 0 }, undefined, nodeWithin, () => "nothing"), 0);
});

test("checkStandsAt judges a candidate by the line's own within when it names one", () => {
  const line = { lat: 47.0, lon: 0.0, within: 5 };
  assert.equal(checkStandsAt("role=start", { lat: 47.0, lon: 0.0 }, line, nodeWithin, () => "nothing"), 0);
  assert.throws(
    () => checkStandsAt("role=start", { lat: 47.0001, lon: 0.0 }, line, nodeWithin, () => "Choose the other role."),
    /role=start is \d+\.\d m from the published timing line, which is not within 5 m\. Choose the other role\./,
  );
});

test("checkStandsAt falls back to the asked allowance when the line names none", () => {
  const far = { lat: 47.0002, lon: 0.0 };
  assert.throws(
    () => checkStandsAt("role=start", far, { lat: 47.0, lon: 0.0 }, nodeWithin, () => ""),
    /which is not within 10 m/,
  );
  assert.ok(checkStandsAt("the atlas lap", far, { lat: 47.0, lon: 0.0 }, measuredWithin, () => "") > 0, "22 m stands at the measurement's allowance");
});

test("checkOrigin measures the atlas lap's start against the published line", () => {
  const published = { lat: 30.1, lon: -97.6 };
  assert.equal(checkOrigin({ lat: 30.1, lon: -97.6 }, published), 0);
  assert.ok(checkOrigin({ lat: 30.1001, lon: -97.6 }, published) < 25, "a tenth of a hundredth of a degree walks");

  // A circuit whose script publishes no line cannot fail this, and says so at nought.
  assert.equal(checkOrigin({ lat: 0, lon: 0 }, undefined), 0);

  assert.throws(
    () => checkOrigin({ lat: 30.101, lon: -97.6 }, published),
    /the atlas lap is \d+\.\d m from the published timing line, which is not within 25 m\. Its markers would be measured from the wrong line\./,
  );
});
