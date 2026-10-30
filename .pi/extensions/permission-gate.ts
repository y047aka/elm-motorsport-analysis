/**
 * The project's permission gate.
 *
 * Pi has no declarative permissions setting, so the three tiers live here:
 *   deny > ask > allow. `allow` needs no rule: pi runs tool calls without
 *   asking, so anything that matches neither list behaves as allowed.
 *
 * A command matches per shell segment (&&, ||, ;, &, |, newline, subshell
 * parentheses, and command substitutions), so a guarded command smuggled
 * behind `&&` or `&` still matches. `nix develop --command` is stripped
 * before matching, since the flake wraps `gh` in it.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/** One rule: a label shown when it fires, and a test on a command segment. */
interface Rule {
	why: string;
	re: RegExp;
}

// Deny: irreversible or reaching outside the repository.
const DENY: Rule[] = [
	{ why: "sudo", re: /\bsudo\b/ },
	{ why: "find -exec / -delete", re: /\bfind\b.*\s(-exec\w*|-delete)\b/ },
	{
		why: "git push --force / -f / --force-with-lease",
		re: /\bgit\b.*\bpush\b.*(?:\s--force(-with-lease)?\b|\s-\w*f\w*(?:\s|$))/,
	},
	{ why: "publish", re: /\b(cargo|pnpm|npm)\s+publish\b/ },
	{ why: "gh release create/delete", re: /\bgh\s+release\s+(create|delete)\b/ },
	{ why: "gh repo delete", re: /\bgh\s+repo\s+delete\b/ },
	{ why: "gh secret", re: /\bgh\s+secret\b/ },
];

// Ask: destructive or state-changing enough to warrant a confirmation.
const ASK: Rule[] = [
	{ why: "git push", re: /\bgit\b.*\bpush\b/ },
	{
		why: "git history/state rewrite",
		re: /\bgit\b.*\b(switch|checkout|restore|reset|rebase|merge|clean)\b/,
	},
	{ why: "git commit --amend", re: /\bgit\b.*\bcommit\b.*--amend\b/ },
	{ why: "git branch delete", re: /\bgit\b.*\bbranch\b.*(\s-D\b|\s-d\b|\s--delete\b)/ },
	{ why: "git stash drop/clear", re: /\bgit\b.*\bstash\b.*\b(drop|clear)\b/ },
	{ why: "git worktree remove/prune", re: /\bgit\b.*\bworktree\b.*\b(remove|prune)\b/ },
	{ why: "pnpm add/remove", re: /\bpnpm\b.*\b(add|remove)\b/ },
	{ why: "npm install", re: /\bnpm\s+(install|i)\b/ },
	{ why: "cargo add/remove/install", re: /\bcargo\s+(add|remove|install)\b/ },
	{ why: "gh api", re: /\bgh\s+api\b/ },
	// Anchored at the segment start: `command -v chmod` asks whether chmod
	// exists and stays allowed.
	{ why: "chmod/chown", re: /^\s*(chmod|chown)\b/ },
	// gh's other writes: reads and pr create/edit run, but merging, closing,
	// commenting or deleting a thing outside the repository confirms.
	{
		why: "gh write",
		re: /\bgh\s+\w+\s+(merge|close|reopen|comment|review|lock|unlock|ready|archive|delete)\b/,
	},
	// Recursive removes confirm. `git rm` does not: it only ever unpaths
	// tracked files, which a checkout undoes.
	{
		why: "recursive rm",
		// Anchored like chmod: `echo rm -rf x` prints, it does not delete.
		// A path-prefixed or wrapped `rm` deletes the same: `/bin/rm`,
		// `nohup rm`, `env FOO=1 rm`. A flag before the recursive one is
		// still recursive: `rm -v -rf`.
		re: /^\s*(?:(?:command|nohup|exec|time)\s+|env(?:\s+\w+=\S+)*\s+)*(?:[\w./-]*\/)?rm\s+(?:-\S+\s+)*(?:-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)(?:\s|$)/,
	},
];

// Deny reading/editing secrets, whatever the tool. `.env` templates are not
// secrets; `deploy.env` ones are.
const SECRET_FILE =
	/(?:^|[\\/])\.env(?:$|\.(?!example\b|sample\b|template\b|dist\b)[a-z]+)|[\w-]\.env$|\.key$|\.pem$/i;

function segments(command: string): string[] {
	// The flake wraps gh in `nix develop --command`; match the wrapped tool.
	let normalized = command.replace(/\bnix\s+develop\s+(?:--command|-c)\s+/g, " ");
	// `gh -R org/repo pr merge` is a gh write past a global flag.
	normalized = normalized.replace(
		/\bgh(\s+(?:-[Rq]|--(?:repo|jq))\s+(?:"[^"]*"|\S+))\s+/g,
		"gh ",
	);
	return normalized.split(/&&|\|\||;|&|\||\n|\$\(|`|[()]/);
}

function match(rules: Rule[], command: string): Rule | undefined {
	const segs = segments(command);
	for (const rule of rules) {
		if (segs.some((s) => rule.re.test(s))) return rule;
	}
	return undefined;
}

function secretPath(input: Record<string, unknown>): string | undefined {
	const p = input.path ?? input.file_path;
	if (typeof p === "string" && SECRET_FILE.test(p)) return p;
	return undefined;
}

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", async (event, ctx) => {
		const input = (event.input ?? {}) as Record<string, unknown>;

		if (["read", "edit", "write"].includes(event.toolName)) {
			const path = secretPath(input);
			if (path) return { block: true, reason: `Denied: ${path} looks like a secret file` };
			return undefined;
		}

		if (event.toolName !== "bash") return undefined;
		const command = String(input.command ?? "");

		const denied = match(DENY, command);
		if (denied) {
			return { block: true, reason: `Denied by project policy (${denied.why})` };
		}

		const ask = match(ASK, command);
		if (!ask) return undefined;

		if (!ctx.hasUI) {
			return { block: true, reason: `Blocked pending confirmation (${ask.why}; no UI to confirm)` };
		}
		const ok = await ctx.ui.confirm(
			`⚠️ ${ask.why}`,
			`Allow this command?\n\n  ${command}`,
		);
		return ok ? undefined : { block: true, reason: "Blocked by user" };
	});
}
