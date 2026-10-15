# label-based-promotion

Working example for **MBC-3938** (Spike: Evaluate a testing + qa two-branch model with label-based PR promotion).

The app is a small to-do list CLI (`src/`). It exists only so that demo PRs change real code. The subject of the example is `.github/`.

## The model

- `testing` is the integration branch. It accepts untested PRs.
- `qa` is the stable branch. It accepts only PRs that passed testing.
- Each feature branch starts from `qa`. It merges into `testing` first (PR 1). After the test, the **same branch** merges into `qa` (PR 2, opened by automation).
- **Rule: never merge `testing` into a feature branch.** A required check enforces it.

```mermaid
flowchart LR
    qa0[(qa)] -->|branch from| F[feature/MBC-123]
    F -->|PR 1| T[(testing)]
    T -.->|QA tests on testing env| L{{label ready-for-qa}}
    L -->|promote-to-qa.yml| G{tested commit?\ndependencies ok?\nbranch clean?\nno conflict?}
    G -->|yes| P[PR 2: same branch -> qa\ndraft]
    G -->|no| B[label promotion-blocked\n+ comment]
    P -->|qa-gate passes, merge| qa1[(qa)]
    qa1 -->|mark-promoted.yml| D[PR 1: ready-for-qa -> promoted-to-qa]
```

## Labels

| Label | Color | Meaning | Who adds it |
|---|---|---|---|
| `depends-on-pr` | `#FBCA04` | This PR needs another PR. The body has `Depends on: #N`. | Automation (from the body) |
| `is-dependency` | `#C5DEF5` | Another PR needs this PR. | Automation |
| `ready-for-qa` | `#0E8A16` | Testing passed. Promote this PR to qa. | QA / developer |
| `promoted-to-qa` | `#5319E7` | The change is in qa. | Automation only |
| `promotion-blocked` | `#B60205` | Automation could not promote. The PR comment has the reason. | Automation |

## Files

| File | Job |
|---|---|
| `.github/workflows/promote-to-qa.yml` | On `ready-for-qa` added to a PR merged into `testing`: check the branch tip is the tested commit, check dependencies, check the branch is clean, check for conflicts with `qa`, open the draft promotion PR. On failure: add `promotion-blocked` and comment with the reason. |
| `.github/workflows/mark-promoted.yml` | On a PR merged into `qa`: find the testing PR with the same head commit, remove `ready-for-qa`, add `promoted-to-qa`. |
| `.github/workflows/dependency-labels.yml` | On PR open or edit: sync `depends-on-pr` / `is-dependency` from `Depends on:` lines. |
| `.github/workflows/guardrail.yml` | Required checks: `no-testing-merge` (PRs into `testing` and `qa`) and `qa-gate` (PRs into `qa`). |
| `.github/workflows/tests.yml` | App tests (`app`) and script tests (`scripts`). |
| `.github/scripts/*.sh` | The logic. Plain bash + `gh` + `jq`, so it can be tested and reused outside Actions. |
| `scripts/setup-repo.sh` | One-time setup: labels, branches, repo settings, branch protection. |
| `tests/*.test.sh` | Script tests. The guardrail tests build a throwaway git repo. The gate tests use a stub `gh`. |

## How the checks work

**qa gate** (`check-qa-gate.sh`, required on every PR into `qa`). It does not trust the PR body. It looks up the merged PR into `testing` from the same branch **with the same head commit**, and passes only when:

1. that PR exists (so commits pushed after PR 1 merged, or a PR that never went through `testing`, fail),
2. it has `ready-for-qa` or `promoted-to-qa`,
3. every `Depends on:` PR of it is already `promoted-to-qa`.

**Dependency gate** (`check-dependencies.sh`). For each `Depends on: #N` PR:

| Dependency label | When `ready-for-qa` is added | On the qa PR (`qa-gate`) |
|---|---|---|
| `promoted-to-qa` | pass | pass |
| `ready-for-qa` | pass. The promotion PR body says to merge the dependency first. | fail until the dependency is in qa |
| other / not found | block | fail |

Only the leading `#N` list after `Depends on:` counts. A line with no `#N` (for example a URL) gives a warning. Dependent branches must start from the dependency branch (stacked), not from `testing`.

**Guardrail** (`check-branch-clean.sh`). A commit "came from testing" when it is on the first-parent chain of `testing` and not in `qa`. Every PR merge into `testing` (merge, squash or rebase) adds commits to that chain. A feature branch's own commits enter `testing` only as the second parent of a merge commit, so they are never on the chain. If a branch merges `testing`, or starts from it, the tip of `testing` becomes reachable from the branch, and the check fails. Merging `qa` into a branch stays allowed. `resolve/*` branches into `testing` are exempt (see conflicts below); they can never reach `qa`, because `no-testing-merge` on the `qa` PR and the clean check in `promote-to-qa` still apply to them.

**Conflict check** (`check-mergeable.sh`). `git merge-tree` test-merges the branch into `qa` without a working tree. On a conflict, the promotion is blocked and the comment lists the files. To fix: merge `qa` into the branch, fix, push, open a new PR into `testing`, and add `ready-for-qa` to the new PR after it is tested. The old PR keeps `ready-for-qa` and `promotion-blocked`; remove them by hand.

## Try it

```bash
npm test                     # app tests
bash tests/run.sh            # script tests
scripts/setup-repo.sh        # labels, qa + testing branches, settings, protection
```

Walk-through on GitHub:

1. `git switch -c feature/MBC-1-due-dates origin/qa`, change `src/todo-list.js`, push, open PR 1 into `testing`, merge it.
2. Add `ready-for-qa` to PR 1. `Promote to qa` opens a draft PR 2 from the same branch into `qa`.
3. Mark PR 2 "Ready for review". The required checks run. Merge PR 2.
4. PR 1 now has `promoted-to-qa`.

Failure demos:

- **Dependency.** Open PR 3 from a branch stacked on an untested branch, with `Depends on: #<that PR>` in the body. Merge into `testing` and add `ready-for-qa`. Result: `promotion-blocked` and a comment.
- **Guardrail.** On a feature branch, run `git merge origin/testing` and push. `no-testing-merge` fails on the PR.
- **Untested commit.** After PR 1 merges, push one more commit to the branch and add `ready-for-qa`. Result: blocked.

Retry after a fix: remove `ready-for-qa` and add it again.

## Findings for the spike

Setup and platform:

- **GITHUB_TOKEN does not start other workflows.** A promotion PR that `GITHUB_TOKEN` opens runs no checks. This example opens it as a draft, and "Ready for review" by a person starts the checks. To run them at once, add a `PROMOTION_TOKEN` secret (GitHub App token preferred). The workflow uses it when it exists.
- **"Allow GitHub Actions to create and approve pull requests"** must be on. The setup script does it.
- **"Automatically delete head branches"** must be off. Otherwise the branch is gone before PR 2. The workflow blocks with a clear message if this happens.
- **`pull_request_target`** is used for the label workflows, so the YAML comes from the current base branch and not from an old merged PR. They check out that same base commit, so the YAML and the scripts always match. They read PR data only and never run PR code.
- **Workflow changes must flow like code.** The label workflows run the copy on `testing` or `qa`, and the guardrail runs scripts from `main`. A change to `.github/` must reach `main`, `qa` and `testing` before it is fully live.

Limits of the guardrail:

- **It stops mistakes, not misuse.** The required checks use `pull_request`, because a required check must report on the PR head commit. So a PR can edit its own copy of `guardrail.yml` to pass. The check scripts come from the default branch, but the YAML does not. For identity, protect `.github/` with CODEOWNERS and code-owner review, or use an org ruleset "Require workflows to pass" from a central repo.
- **Conflicts with `testing`.** `testing` collects many untested PRs, so PR 1 often has conflicts. GitHub's "Resolve conflicts" and "Update branch" buttons merge `testing` into the feature branch, and the guardrail then blocks the branch. The spike says: fix the conflict in a merge commit on `testing`, never in the feature branch. On GitHub, that needs a short-lived branch from `testing` named `resolve/<ticket>` that merges the feature branch and fixes the conflict, merged into `testing` by its own PR. The guardrail exempts `resolve/*` into `testing`. The exemption is by branch name only, so any developer can use it to land a `testing` merge in `testing` (not in `qa`). If identity needs more control, a ruleset can limit who can push `resolve/*` refs. PR 1 then shows as merged when its head commit reaches `testing` (verify in the demo). Measure how often this happens before go / no-go.
- **A sprint reset of `testing` forgives old mistakes.** A branch that merged the old `testing` passes after the reset. The old untested commits are then "not in testing", so the rule no longer sees them. Reset only when no such branch is open.
- **Fast-forward pushes to `testing`** (outside a PR) would put feature commits on the first-parent chain and cause false positives. The setup script requires a PR for `testing` and `qa`. The sprint reset of `testing` is a manual repo-admin push.

Other limits:

- **`qa-gate` does not re-run** when a dependency is promoted later. Re-run the check, or push to the branch. A follow-up could re-trigger dependents from `mark-promoted.yml`.
- **`is-dependency` is not removed** when a `Depends on:` line is deleted, because another PR may still depend on it.
- **`promoted-to-qa` added by hand** is not prevented. A person who adds it to a dependency gets past the dependency gate.
- **Commit SHAs are equal in `testing` and `qa`** only when PRs into `testing` use "Create a merge commit". With squash or rebase into `testing`, `qa` still gets the original branch commits, but `testing` has copies.
- **Fork PRs** are out of scope. The workflows assume same-repo branches (true for identity).
- **Off-the-shelf backport actions** (for example `korthout/backport-action`) cherry-pick commits onto a new branch. This model reuses the original branch, so a small `gh` script fits better.
