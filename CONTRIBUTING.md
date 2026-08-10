# Contributing to NodeWatch

## Repository workflow

`main` is protected conceptually and should be protected in GitHub: changes belong on a focused feature branch and reach `main` through a reviewed pull request with the `quality` check passing.

A branch should represent a logical review unit, not each individual edit. Keep small related fixes together; split work when the changes can be reviewed, released, or reverted independently.

## One-time setup

Install Xcode and Homebrew, then run:

```sh
make bootstrap
```

This installs the versions of SwiftFormat, SwiftLint, and Periphery tracked by the `Brewfile`, and enables the repository's hooks through `core.hooksPath`.

The pre-commit hook prevents commits on `main` and runs formatting, linting, and tests. The pre-push hook prevents direct pushes to `main` and runs the complete CI-equivalent check.

## Working on a change

Create one descriptive branch for the complete reviewable change:

```sh
git switch main
git pull --ff-only
git switch -c feature/descriptive-name
```

During development:

```sh
make format
make test
```

Before requesting review:

```sh
make check
```

Open a pull request using the repository template. Include the user-visible outcome, important implementation decisions, verification performed, and any manual testing still required.

## Testing approach

Tests use Apple's Swift Testing framework and live in `Tests/NodeWatchTests`. Prefer small deterministic tests around behavior in `NodeWatchCore`. Keep shell commands, workspace state, and live processes behind the application boundary so the core remains fast and safe to test.

Manual smoke testing is required when a change touches:

- process and port discovery;
- HTTP probing;
- opening browsers, Terminal, or Finder;
- process termination;
- application packaging, signing, updates, or notarization.

## GitHub settings

After the repository has been pushed to GitHub, configure a branch ruleset for `main` that:

- requires a pull request before merging;
- requires at least one approval;
- dismisses stale approvals when new commits are pushed;
- requires the `quality` status check;
- requires conversation resolution;
- blocks force pushes and deletion; and
- applies to administrators too.
