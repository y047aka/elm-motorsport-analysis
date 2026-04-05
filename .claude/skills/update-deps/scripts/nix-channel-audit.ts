// Audit the current nixpkgs channel in flake.nix and report whether
// a newer stable channel is available.
// Run from the project root.
const flake = Deno.readTextFileSync("flake.nix");
const m = flake.match(/nixpkgs\/nixpkgs-(\d+)\.(\d+)-darwin/);
if (!m) {
  console.log("channel: unknown");
  Deno.exit(0);
}
const [, yy, mm] = m;
console.log(`current channel: nixpkgs-${yy}.${mm}-darwin`);

const now = new Date();
const year = now.getFullYear() % 100;

const channels = Array.from({ length: year - 24 + 1 }, (_, i) => 24 + i)
  .flatMap((y) =>
    [5, 11]
      .filter((month) => new Date(2000 + y, month - 1, 1) <= now)
      .map((month) => {
        const mm2 = String(month).padStart(2, "0");
        return { y, mm: mm2, label: `${y}.${mm2}` };
      })
  );

const latest = channels.at(-1);
if (!latest) {
  console.log("latest channel: unknown");
  Deno.exit(0);
}

const currentNum = parseInt(yy) * 100 + parseInt(mm);
const latestNum = latest.y * 100 + parseInt(latest.mm);

if (latestNum > currentNum) {
  console.log(
    `latest channel:  nixpkgs-${latest.label}-darwin  <- UPGRADE AVAILABLE`,
  );
} else {
  console.log(
    `latest channel:  nixpkgs-${latest.label}-darwin  (up to date)`,
  );
}
