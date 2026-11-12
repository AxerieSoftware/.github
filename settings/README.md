# Repo settings

`repos.json` lists every repo and the settings it should have; `apply.sh` makes it so.

```
settings/apply.sh            # show drift
settings/apply.sh --apply    # fix it
```

On the Free plan, private repos can't have rulesets, branch protection or GitHub auto-merge. That's
why `dependabot-auto-merge.yml` waits for the other checks itself, and why only the public repos
set `allow_auto_merge`.

When a repo is added, add a line to `repos.json`. The weekly lab audit can run `apply.sh` and
report drift.
