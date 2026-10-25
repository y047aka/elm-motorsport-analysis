// The one question the survey asks of a place on the earth: does it stand
// where the circuit says its line stands — beside the published line's own
// narrowing of the allowance. The measured line's wider allowance is
// `circuits/test/TestTrack.flix`'s to hold now.

import assert from "node:assert/strict";
import { test } from "node:test";

import { checkStandsAt, nodeWithin } from "../timing-line.ts";

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
});

