# Project instructions

- Respond to the user in Japanese.
- Do not add a `Co-Authored-By:` trailer to commit messages.
- `.pi/extensions/permission-gate.ts` enforces allow/confirm/deny for bash
  commands; any other bash may run without confirmation. Secret files
  (`.env*`, `*.key`, `*.pem`) are blocked by the gate in the `read`, `edit`
  and `write` tools, but **bash is not blocked**: never read or write them
  through commands like `cat .env`.
