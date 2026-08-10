# NodeWatch

## Git workflow

- Never commit or push directly to `main`. All changes go through a feature branch and a reviewed pull request.
- Use one branch for one coherent, reviewable block of work. Keep follow-up fixes for that block on the same branch; do not create a new branch for every small edit.
- Split unrelated features or independently reviewable changes into separate branches and pull requests.
- Prefer branch names such as `feature/menu-search`, `fix/process-cycle`, or `chore/repository-tooling`. Codex-created branches use the `codex-gaz/` prefix.
- Keep commits meaningful. A compact change can be one commit; larger work should be checkpointed at coherent, verified boundaries.
- Stage explicit paths. Do not blanket-stage ignored, generated, secret, or unrelated files.
- Do not force-push, rewrite shared history, merge a pull request, or publish a release unless the user explicitly asks.
- Before opening or updating a pull request, run `make check` and summarize what was verified.

GitHub branch protection must require a pull request and the `quality` status check before merging to `main`. Repository rules are documented here as the local source of truth; enforcement is configured in GitHub repository settings.

## Development standards

- Support macOS 14 and Swift 6 unless the project requirements are deliberately changed.
- Keep reusable, UI-independent behavior in `NodeWatchCore` and cover it with Swift Testing tests.
- Add or update tests in the same change as observable behavior.
- Use SwiftFormat for formatting, SwiftLint for linting, and Periphery for dead-code analysis. Do not hand-format around their configured rules.
- Treat warnings from the strict quality gate as failures.
- Never commit build products, local caches, editor state, credentials, signing material, notarization credentials, Sparkle private keys, or environment files.
- NodeWatch must continue to work without administrator privileges and without App Sandbox access; process discovery relies on `ps` and `lsof` as the current user.

## Verification

- `make test`: build and run the Swift Testing suites.
- `make format-check`: verify formatting without modifying files.
- `make lint`: run SwiftLint in strict mode.
- `make doctor`: build tests and run Periphery.
- `make check`: run the full local and CI quality gate.
- `make format`: apply formatting when required.

Use `make check` before handing work back. App behavior involving process discovery, browser/Terminal/Finder integration, or process termination also needs a manual smoke test because unit tests cannot safely cover those macOS integrations end to end.
