// Report pinned revision dates and hashes from flake.lock.
// Run from the project root.

interface FlakeLocked {
  lastModified?: number;
  rev?: string;
}

interface FlakeNode {
  locked?: FlakeLocked;
}

interface FlakeLock {
  nodes?: Record<string, FlakeNode>;
}

function isFlakeLock(v: unknown): v is FlakeLock {
  return typeof v === "object" && v !== null;
}

const raw: unknown = JSON.parse(Deno.readTextFileSync("flake.lock"));
if (!isFlakeLock(raw)) {
  console.error("unexpected flake.lock format");
  Deno.exit(1);
}
const d = raw;

(Object.entries(d.nodes ?? {}) as [string, FlakeNode][])
  .filter(
    (entry): entry is [string, { locked: FlakeLocked }] =>
      entry[1].locked != null,
  )
  .forEach(([k, { locked }]) => {
    const ts = locked.lastModified ?? 0;
    const date = new Date(ts * 1000).toISOString().slice(0, 10);
    const rev = (locked.rev ?? "?").slice(0, 12);
    console.log(`${k}: pinned ${date} (rev ${rev})`);
  });
