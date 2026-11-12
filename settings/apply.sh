#!/usr/bin/env bash

# Applies repos.json to every repo it lists: merge settings, features, Dependabot alerts and
# security updates. Idempotent. Rulesets and branch protection aren't here: the org is on the Free
# plan, where private repos can't have them.
#
#   settings/apply.sh            # show what would change
#   settings/apply.sh --apply    # change it
#
# Needs a gh login with admin on the repos.

set -euo pipefail

conf="$(dirname "$0")/repos.json"
apply=${1:-}
owner=$(jq -r .owner "$conf")
drift=0

for repo in $(jq -r '.repos | keys[]' "$conf"); do
	want=$(jq -c --arg r "$repo" '.defaults + .repos[$r]' "$conf")
	have=$(gh api "repos/$owner/$repo" | jq -c --argjson want "$want" 'with_entries(select(.key as $k | $want | has($k)))')
	diff=$(jq -rn --argjson want "$want" --argjson have "$have" \
		'$want | to_entries[] | select($have[.key] != .value) | "\(.key): \($have[.key]) -> \(.value)"')

	if [ -n "$diff" ]; then
		drift=1
		echo "$repo"
		sed 's/^/  /' <<<"$diff"
		[ "$apply" = --apply ] && gh api -X PATCH "repos/$owner/$repo" --input - <<<"$want" --silent
	fi

	if [ "$(jq -r .security.vulnerability_alerts "$conf")" = true ] && ! gh api "repos/$owner/$repo/vulnerability-alerts" --silent 2>/dev/null; then
		drift=1
		echo "$repo"
		echo "  Dependabot alerts: off -> on"
		[ "$apply" = --apply ] && gh api -X PUT "repos/$owner/$repo/vulnerability-alerts" --silent
	fi

	if [ "$(jq -r .security.automated_security_fixes "$conf")" = true ] &&
		[ "$(gh api "repos/$owner/$repo/automated-security-fixes" -q .enabled 2>/dev/null)" != true ]; then
		drift=1
		echo "$repo"
		echo "  Dependabot security updates: off -> on"
		[ "$apply" = --apply ] && gh api -X PUT "repos/$owner/$repo/automated-security-fixes" --silent
	fi
done

if [ "$drift" = 0 ]; then
	echo "Every repo matches repos.json."
elif [ "$apply" != --apply ]; then
	echo
	echo "Run with --apply to change these."
fi
