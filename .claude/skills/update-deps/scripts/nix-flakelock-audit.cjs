// Report pinned revision dates and hashes from flake.lock.
// Run from the project root.
const d = JSON.parse(require("fs").readFileSync("flake.lock", "utf8"));
for (const [k, v] of Object.entries(d.nodes || {})) {
  if (v.locked) {
    const ts = v.locked.lastModified || 0;
    const date = new Date(ts * 1000).toISOString().slice(0, 10);
    const rev = (v.locked.rev || "?").slice(0, 12);
    console.log(k + ": pinned " + date + " (rev " + rev + ")");
  }
}
