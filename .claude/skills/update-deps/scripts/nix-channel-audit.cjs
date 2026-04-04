// Audit the current nixpkgs channel in flake.nix and report whether
// a newer stable channel is available.
// Run from the project root.
const fs = require("fs");
const flake = fs.readFileSync("flake.nix", "utf8");
const m = flake.match(/nixpkgs\/nixpkgs-(\d+)\.(\d+)-darwin/);
if (!m) {
  console.log("channel: unknown");
  process.exit(0);
}
const [, yy, mm] = m;
console.log("current channel: nixpkgs-" + yy + "." + mm + "-darwin");

const now = new Date();
const year = now.getFullYear() % 100;

const channels = [];
for (let y = 24; y <= year; y++) {
  for (const releaseMonth of [5, 11]) {
    const releaseDate = new Date(2000 + y, releaseMonth - 1, 1);
    if (releaseDate <= now) {
      const mm2 = String(releaseMonth).padStart(2, "0");
      channels.push({ y, mm: mm2, label: y + "." + mm2 });
    }
  }
}

const latest = channels[channels.length - 1];
const currentNum = parseInt(yy) * 100 + parseInt(mm);
const latestNum = latest.y * 100 + parseInt(latest.mm);

if (latestNum > currentNum) {
  console.log(
    "latest channel:  nixpkgs-" +
      latest.label +
      "-darwin  <- UPGRADE AVAILABLE"
  );
} else {
  console.log(
    "latest channel:  nixpkgs-" + latest.label + "-darwin  (up to date)"
  );
}
