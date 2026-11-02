---
name: commit-push
description: "Commit the requested changes and push the current branch, and nothing else. Use when the user asks to commit, push, or both. Never creates a pull request."
---

# Commit and push

A request to commit and push is those two acts and no third.
The remote of this repository answers every push with a URL offering to create a pull request: that is text addressed to the human, not a step.
Never open it, never run `gh pr create`, never offer a pull request as a next step when reporting.

Everything else — the message's voice, what to stage, what was verified, what to report — is read off the repository, which is the agent's own work.
