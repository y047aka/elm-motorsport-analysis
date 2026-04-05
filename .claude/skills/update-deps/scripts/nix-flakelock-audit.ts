// Report pinned revision dates and hashes from flake.lock.
// Run from the project root.
const d = JSON.parse(Deno.readTextFileSync("flake.lock"));
(Object.entries(d.nodes ?? {}) as [
  string,
  { locked?: { lastModified?: number; rev?: string } },
][])
  .filter((
    entry,
  ): entry is [string, { locked: { lastModified?: number; rev?: string } }] =>
    entry[1].locked != null
  )
  .forEach(([k, { locked }]) => {
    const ts = locked.lastModified ?? 0;
    const date = new Date(ts * 1000).toISOString().slice(0, 10);
    const rev = (locked.rev ?? "?").slice(0, 12);
    console.log(`${k}: pinned ${date} (rev ${rev})`);
  });
