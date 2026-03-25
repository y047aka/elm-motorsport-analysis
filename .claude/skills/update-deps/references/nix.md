# Nix

## Audit

No dry-run available. Report pinned revision dates from `flake.lock`:

```bash
cat flake.lock | python3 -c "
import json, sys, datetime
d = json.load(sys.stdin)
for k, v in d.get('nodes', {}).items():
    if 'locked' in v:
        ts = v['locked'].get('lastModified', 0)
        date = datetime.datetime.fromtimestamp(ts).strftime('%Y-%m-%d')
        rev = v['locked'].get('rev', '?')[:12]
        print(f'{k}: pinned {date} (rev {rev})')
"
```

## Update

```bash
nix flake update
```

## Verify

```bash
nix run .#test
nix run .#cli-test
nix run .#build
```
