# NodeWatch

NodeWatch is a native macOS menu-bar app for seeing which Node.js development services are running on your Mac. It discovers local processes and ports, groups related processes, shows CPU and memory use, opens web services and project folders, and can gracefully stop a service.

The project supports three distinct workflows:

1. **Run from source** while developing: `make run`
2. **Build an installable development app** for your own Mac: `make app`
3. **Create a public release** for the website: `./scripts/release.sh`

The first two require no Apple Developer account. Public releases require Developer ID signing, Apple notarization, permanent website URLs, and a Sparkle update-signing key.

## What NodeWatch does

- Lives in the macOS menu bar and also provides a normal app window.
- Finds Node.js, npm, pnpm, Yarn, Bun, Deno, Expo, and related development processes.
- Detects listening TCP ports and probes localhost HTTP endpoints.
- Opens confirmed HTML services in the default browser.
- Classifies Web, Mobile, API, Agent, Tool, and generic Process workloads.
- Nests child processes beneath their monitored parents.
- Samples per-process CPU and resident memory usage.
- Shows project, PID, uptime, command, and listening ports.
- Opens a Terminal window in a process working directory.
- Reveals project folders in Finder.
- Gracefully stops a process by sending `SIGTERM`.
- Allows project roots, detection markers, refresh rate, visibility, and terminal app to be configured.

NodeWatch runs `ps` and `lsof` as the current user. It does not request administrator access. The app is intentionally not App-Sandboxed because process discovery is its core function; public builds still use Apple's hardened runtime.

## Requirements

- macOS 14 Sonoma or newer
- An Apple Silicon or Intel Mac
- The full Xcode application with the Swift toolchain
- Homebrew only if you want the formatting, linting, and analysis tools

Check the toolchain from Terminal:

```sh
xcodebuild -version
swift --version
```

If those commands point at Command Line Tools instead of the full Xcode installation, select Xcode:

```sh
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

## Quick start: launch the app as a developer

Open Terminal, change into this repository, and run:

```sh
cd /path/to/nodewatch
make run
```

On the first run, Swift Package Manager downloads and builds Sparkle, so it takes longer than later launches. NodeWatch opens its main window and adds a server icon to the menu bar. Keep that Terminal window open while the app runs; press `Control-C` there to stop it.

You do **not** need to configure Sparkle, signing, notarization, or an account to run the app as a developer. The Settings screen will say automatic updates are disabled because source builds are not published releases.

### One-time development setup

For the complete quality-tool setup, install [Homebrew](https://brew.sh/) and run:

```sh
make bootstrap
```

This installs SwiftFormat, SwiftLint, and Periphery from the tracked `Brewfile`, then enables the repository's pre-commit hook. It is useful for contributing but is not required just to run NodeWatch.

### Run from Xcode

You can also open the Swift package directly in Xcode:

```sh
open Package.swift
```

Select the `NodeWatch` scheme and **My Mac**, then click Run or press `Command-R`. Terminal's `make run` is the most predictable path because it supplies the writable package/module caches and sandbox flags used by this project.

## Everyday development commands

| Command | Purpose |
| --- | --- |
| `make run` | Build and launch NodeWatch from source. |
| `make build` | Compile a debug build without launching it. |
| `make app` | Build an installable, universal development `.app`. |
| `make test` | Run the Swift Testing suites. |
| `make format` | Apply SwiftFormat. |
| `make format-check` | Check formatting without changing files. |
| `make lint` | Run SwiftLint in strict mode. |
| `make doctor` | Build the tests and run Periphery dead-code analysis. |
| `make coverage` | Run tests with LLVM code coverage. |
| `make check` | Run the same formatting, lint, test, and analysis gate as CI. |
| `make clean` | Remove Swift Package Manager build products. |

GitHub Actions runs `make ci`, which is the same gate as `make check`, on pushes and pull requests.

## Contributing

Do not commit or push directly to `main`. Use one feature branch for each coherent, reviewable block of work and merge it through a pull request after `make check` passes. Small related fixes belong on the same branch; unrelated or independently reversible work belongs in a separate pull request.

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, testing, hooks, and the GitHub branch-protection settings, and [AGENTS.md](AGENTS.md) for the repository rules followed by coding agents.

## Build an installable development app

Running from source is best while coding. To make a normal app bundle that can be opened from Finder:

```sh
make app
open outputs/NodeWatch.app
```

The result is:

```text
outputs/NodeWatch.app
```

By default, the builder:

- creates a universal `arm64` and `x86_64` binary;
- embeds `Sparkle.framework` and its helper processes;
- writes the app's `Info.plist`;
- uses version `0.1.0`, build `1`, and bundle ID `dev.gaz.nodewatch`;
- ad-hoc signs the app for local use; and
- omits the Sparkle feed and key, so updates stay disabled.

This bundle is suitable for your own development Mac. It is **not** suitable for public download because it is not signed with your Developer ID certificate or notarized by Apple.

For a quicker Apple-Silicon-only local build:

```sh
NODEWATCH_ARCHS=arm64 make app
```

The build script accepts these optional settings:

| Variable | Development default | Meaning |
| --- | --- | --- |
| `NODEWATCH_VERSION` | `0.1.0` | User-facing marketing version. |
| `NODEWATCH_BUILD_NUMBER` | `1` | Positive internal build number. |
| `NODEWATCH_BUNDLE_ID` | `dev.gaz.nodewatch` | Stable reverse-DNS app identifier. |
| `NODEWATCH_ARCHS` | `arm64 x86_64` | Architectures to include. |
| `NODEWATCH_SIGNING_IDENTITY` | `-` | Codesigning identity; `-` means ad-hoc. |
| `SPARKLE_FEED_URL` | unset | HTTPS URL of `appcast.xml`. |
| `SPARKLE_PUBLIC_KEY` | unset | Public EdDSA update-verification key. |

`SPARKLE_FEED_URL` and `SPARKLE_PUBLIC_KEY` must be supplied together. Normal development builds should leave both unset.

## How public distribution works

NodeWatch is intended to be downloaded directly from the product website rather than submitted to the Mac App Store.

A public release goes through this chain:

1. Swift builds a universal release binary.
2. Sparkle and its nested helpers are embedded in `NodeWatch.app`.
3. Every executable is signed with a **Developer ID Application** certificate and Apple's hardened runtime.
4. The app is zipped and submitted to Apple's notary service.
5. Apple's notarization ticket is stapled to the app.
6. The final app ZIP is signed with a separate Sparkle **EdDSA** key.
7. Sparkle generates or updates `appcast.xml`.
8. The ZIP and appcast are uploaded to a GitHub Release.
9. GitHub Pages publishes the website and latest appcast at `nodewatch.gaz.dev`.
10. Installed copies periodically read the appcast and can securely download and install the new release.

There are two independent trust systems:

- **Developer ID and notarization** tell macOS and Gatekeeper who published the app and that Apple scanned it.
- **Sparkle EdDSA signatures** let an installed copy of NodeWatch verify that an update and its appcast were produced by us.

Both are required by the release script. The Sparkle private key remains in your login Keychain and must never be committed or uploaded to the website.

## One-time public-release setup

Do these steps once before the first release.

### 1. Permanent identity and URLs

NodeWatch uses these permanent release values:

- Bundle identifier: `dev.gaz.nodewatch`
- Product/download page: `https://nodewatch.gaz.dev/`
- Sparkle appcast: `https://nodewatch.gaz.dev/appcast.xml`
- Release downloads: `https://github.com/garylesueur/nodewatch/releases`

Changing the bundle identifier later makes macOS treat the result as a different app and separates its saved preferences. Changing the feed URL requires releasing an app update that knows the new URL before the old location disappears.

### 2. Obtain a Developer ID certificate

Join the [Apple Developer Program](https://developer.apple.com/programs/), create a **Developer ID Application** certificate, and install it in your login Keychain. Confirm that codesign can see it:

```sh
security find-identity -v -p codesigning
```

Copy the complete identity shown there, for example:

```text
Developer ID Application: Example Company (TEAMID)
```

Do not use an Apple Development, Mac Development, or Mac App Distribution identity for direct website releases.

### 3. Save notarization credentials

Create an app-specific password for the Apple ID, then store the notarization credentials in Keychain under a memorable profile name:

```sh
xcrun notarytool store-credentials nodewatch-notary \
  --apple-id "you@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "APP_SPECIFIC_PASSWORD"
```

The release command later refers to `nodewatch-notary`; the password does not go into the repository or shell script.

### 4. Generate the Sparkle update key

Build once so Swift Package Manager downloads Sparkle and its tools:

```sh
make build
```

Generate the key using a NodeWatch-specific Keychain account:

```sh
.build/artifacts/sparkle/Sparkle/bin/generate_keys --account nodewatch
```

The command prints a base64 public key. Save that value as `SPARKLE_PUBLIC_KEY`. The private key stays in Keychain and is used by `generate_appcast`.

Back up the private key to encrypted, access-controlled storage. The exported file is as sensitive as a password:

```sh
.build/artifacts/sparkle/Sparkle/bin/generate_keys \
  --account nodewatch \
  -x /secure/location/nodewatch-sparkle-private-key
```

Never commit that exported file, put it in `outputs/`, or upload it to the website.

## Create a public release

Pick a semantic marketing version and a monotonically increasing integer build number. The build number must increase for every published build, including rebuilds of the same marketing version.

From the repository root, run:

```sh
NODEWATCH_VERSION=1.0.0 \
NODEWATCH_BUILD_NUMBER=100 \
NODEWATCH_SIGNING_IDENTITY="Developer ID Application: Example Company (TEAMID)" \
SPARKLE_PUBLIC_KEY="BASE64_PUBLIC_KEY" \
SPARKLE_KEY_ACCOUNT=nodewatch \
NOTARYTOOL_PROFILE=nodewatch-notary \
./scripts/release.sh
```

Replace the signing identity and public key with the real values. The bundle identifier, website, appcast, and GitHub Release URL are project defaults. Do not add credentials or private keys to a tracked script.

The release script refuses to continue if required values are missing, the build number is invalid, update URLs are not HTTPS, or the signing identity is ad-hoc. It then:

- runs the universal app builder;
- signs Sparkle's helpers and the app from the inside out;
- verifies the code signature;
- submits the ZIP with `notarytool` and waits for Apple;
- staples and validates the notarization ticket;
- recreates the final ZIP;
- signs the archive and appcast with Sparkle; and
- asks Gatekeeper to assess the finished app.

Successful output is written to:

```text
outputs/NodeWatch.app
outputs/updates/NodeWatch-1.0.0.zip
outputs/updates/appcast.xml
```

Sparkle may also create delta update files and an `old_updates/` directory as more versions accumulate.

## Publish with GitHub Releases and Pages

Authenticate the GitHub CLI, then create a draft release from the verified local output:

```sh
gh auth login -h github.com
NODEWATCH_VERSION=1.0.0 ./scripts/publish-release.sh
```

The command attaches the signed/notarized ZIP, signed appcast, and any delta updates to a draft GitHub Release. Review the draft in GitHub and publish it only after the release smoke test passes.

Publishing the release triggers the Pages workflow. It deploys the landing page from `site/` and copies the newest release's `appcast.xml` to `https://nodewatch.gaz.dev/appcast.xml`. The website's download button points to the latest GitHub Release.

Configure GitHub Pages to use GitHub Actions and set its custom domain to `nodewatch.gaz.dev`. At the DNS provider for `gaz.dev`, create this record:

```text
Type: CNAME
Name: nodewatch
Value: garylesueur.github.io
```

Keep previous archives in `outputs/updates/` when generating later appcasts. Sparkle preserves older feed entries and can create smaller delta updates. Do not publish until every newly generated file referenced by the appcast is attached to the new release and older referenced files remain available from their original releases.

## Test a release before announcing it

Never make the first update test on the entire user base. Before publishing or announcing:

1. Run `make check`.
2. Create the signed/notarized release.
3. Confirm the ZIP expands normally.
4. Move the app to `/Applications` on a clean Mac user account or test Mac.
5. Confirm Gatekeeper opens it without an unidentified-developer warning.
6. Confirm the main window and menu-bar item both appear.
7. Start representative Node, Next.js, Vite, Expo, and API processes.
8. Test browser opening, Finder reveal, Terminal opening, and graceful termination.
9. Install the previous public version and use **Check for Updates…** to update to the new version.
10. Confirm settings survive the update and the relaunched app reports the new version.

Sparkle asks on the second launch whether it may check for updates automatically and whether updates may download automatically. Users can always make a manual check from the app menu, menu-bar panel, or Settings.

## Releasing the next version

For every later release:

1. Update the marketing version and increment the integer build number.
2. Add release notes next to the archive if desired; Sparkle accepts matching `.html`, `.md`, or `.txt` filenames.
3. Run the same `scripts/release.sh` command with the new numbers.
4. Run `NODEWATCH_VERSION=x.y.z ./scripts/publish-release.sh` and review the draft.
5. Publish the GitHub Release; Pages deploys the updated appcast automatically.
6. Test updating from the previous public version.

Keep these values stable across releases:

- `NODEWATCH_BUNDLE_ID`
- `SPARKLE_FEED_URL`
- `SPARKLE_PUBLIC_KEY`
- `SPARKLE_KEY_ACCOUNT`

Keep both the Developer ID certificate and Sparkle private key backed up securely. Losing either complicates future releases and key rotation.

## Sign-in status

Sign-in is not currently implemented and is not required for downloading, installing, monitoring local processes, or receiving updates.

Add sign-in only when NodeWatch has a real account-backed capability, such as paid entitlements, synced settings, or team features. The intended native macOS design is:

1. Open the identity provider in the system browser.
2. Use OAuth 2.0 Authorization Code with PKCE.
3. Return through a registered callback URL.
4. Exchange the one-time code through the production backend.
5. Store short-lived access and refresh tokens in macOS Keychain.

Do not embed an OAuth client secret in the app. Before implementing authentication, choose the identity provider, production API and callback domains, and exactly what signing in unlocks. Local monitoring should continue to work offline unless licensing intentionally requires otherwise.

## Troubleshooting

### `make run` cannot find Xcode or the macOS SDK

Confirm the full Xcode app is installed and selected:

```sh
xcode-select -p
xcodebuild -version
```

The selected developer path should normally be `/Applications/Xcode.app/Contents/Developer`.

### The first build appears stuck

Swift Package Manager may be downloading the Sparkle binary artifact. Check the Terminal output and allow it to finish. Later builds use the local package cache.

### Swift reports module-cache or sandbox errors

Use the Make targets rather than invoking `swift` manually. They create a writable cache under `work/` and pass the sandbox flags expected by this project:

```sh
make build
make test
```

### Settings says automatic updates are disabled

That is expected for `make run` and the default `make app`. Updates are only configured when a release build contains both `SPARKLE_FEED_URL` and `SPARKLE_PUBLIC_KEY`.

### A public release fails codesigning

List the identities available in Keychain and copy the exact Developer ID Application name:

```sh
security find-identity -v -p codesigning
```

The certificate must include its private key and must be usable by the current login account.

### Notarization fails

Check the `notarytool` output first. Confirm the keychain profile name, Team ID, app-specific password, Developer ID identity, hardened runtime, and secure timestamp. Apple returns a submission ID that can be used to retrieve the detailed notarization log.

### Sparkle finds no update

Check all of the following:

- The new `NODEWATCH_BUILD_NUMBER` is greater than the installed build number.
- The installed app's feed URL is the public `appcast.xml` URL.
- The feed and every referenced archive are reachable over HTTPS.
- The appcast was uploaded after its archives.
- The release uses the same Sparkle key account and public key as earlier versions.
- A CDN is not serving a stale appcast.

## Project layout

```text
Package.swift                 Swift Package manifest and Sparkle dependency
Package.resolved              Resolved dependency versions
Sources/NodeWatch/            macOS app, SwiftUI views, scanner, and updater
Sources/NodeWatchCore/        dependency-free process and endpoint models
Tests/NodeWatchTests/         Swift Testing suites
scripts/build-app.sh          universal `.app` builder and codesigner
scripts/release.sh            notarization, archive, and appcast workflow
scripts/run-periphery.sh      dead-code analysis helper
Brewfile                      pinned development-tool list
Makefile                      short development and quality commands
.github/workflows/ci.yml      pull request and push validation
outputs/                      local app and release output; ignored by Git
work/                         local compiler/tool caches; ignored by Git
```

## Further reading

- [Apple: Distribution overview](https://developer.apple.com/documentation/technologyoverviews/distribution)
- [Apple: Signing Mac software with Developer ID](https://developer.apple.com/developer-id/)
- [Apple: Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Sparkle documentation](https://sparkle-project.org/documentation/)
- [Sparkle publishing guide](https://sparkle-project.org/documentation/publishing/)
- [Sparkle customization and update preferences](https://sparkle-project.org/documentation/customization/)
