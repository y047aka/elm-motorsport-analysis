branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$branch" = "HEAD" ] || [ "$branch" = "main" ]; then
  echo "update-snapshots-ci: check out the branch whose snapshots you want updated (on '$branch')" >&2
  exit 1
fi

# The dispatch hands back nothing to watch, so the run has to be
# found afterwards -- and only a run that was not already there
# is this one.
before=$(gh run list --workflow update-snapshots.yml --branch "$branch" --limit 1 --json databaseId --jq '.[0].databaseId // 0')
echo "Dispatching update-snapshots.yml on $branch" >&2
gh workflow run update-snapshots.yml --ref "$branch"

run=$before
attempt=0
while [ "$run" = "$before" ] && [ "$attempt" -lt 30 ]; do
  sleep 2
  attempt=$((attempt + 1))
  run=$(gh run list --workflow update-snapshots.yml --branch "$branch" --limit 1 --json databaseId --jq '.[0].databaseId // 0')
done
if [ "$run" = "$before" ]; then
  echo "update-snapshots-ci: the run never appeared; watch it with 'gh run list --workflow update-snapshots.yml'" >&2
  exit 1
fi

gh run watch "$run" --exit-status

before_head=$(git rev-parse HEAD)
# Named rather than left to the upstream: a branch pushed with
# `git push origin HEAD` has none to pull from.
git pull --ff-only origin "$branch"
head_sha=$(git rev-parse HEAD)
if [ "$head_sha" = "$before_head" ]; then
  echo "The baselines were already current; nothing was pushed." >&2
  exit 0
fi

# The commit that just arrived is the bot's, and GitHub holds the
# workflows a bot's push would start rather than running them. Left
# alone, the pull request keeps the red check that sent you here and
# gets no run to replace it.
held=""
attempt=0
while [ -z "$held" ] && [ "$attempt" -lt 10 ]; do
  sleep 3
  attempt=$((attempt + 1))
  held=$(SHA="$head_sha" gh run list --branch "$branch" --limit 20 --json databaseId,headSha,conclusion --jq '[.[] | select(.headSha == env.SHA and .conclusion == "action_required") | .databaseId] | .[]')
done

if [ -z "$held" ]; then
  echo "No run is waiting on approval." >&2
else
  printf '%s\n' "$held" | while IFS= read -r id; do
    gh api -X POST "repos/{owner}/{repo}/actions/runs/$id/approve" >/dev/null
    echo "Approved run $id." >&2
  done
fi
