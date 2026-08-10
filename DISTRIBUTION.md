# Distributing NodeWatch

NodeWatch is distributed from [nodewatch.gaz.dev](https://nodewatch.gaz.dev) using GitHub Releases and GitHub Pages. A production release is built as a universal app, Developer ID signed, notarized and stapled by Apple, then signed for Sparkle automatic updates.

Permanent release identity:

- Bundle identifier: `dev.gaz.nodewatch`
- Website: `https://nodewatch.gaz.dev/`
- Appcast: `https://nodewatch.gaz.dev/appcast.xml`
- Release assets: `https://github.com/garylesueur/nodewatch/releases`

## One-time Apple setup

1. Install a `Developer ID Application` certificate in the login keychain.
2. Store notarization credentials in Keychain:

   ```sh
   xcrun notarytool store-credentials nodewatch-notary \
     --apple-id "you@example.com" \
     --team-id "YOUR_TEAM_ID" \
     --password "APP_SPECIFIC_PASSWORD"
   ```

3. Build once and generate the Sparkle EdDSA key:

   ```sh
   make build
   .build/artifacts/sparkle/Sparkle/bin/generate_keys --account nodewatch
   ```

The Sparkle private key remains in Keychain. Back it up securely and never commit or upload it. Save the printed public key for `SPARKLE_PUBLIC_KEY`.

## One-time hosting setup

1. In the repository's Pages settings, select **GitHub Actions** as the source.
2. Set the custom domain to `nodewatch.gaz.dev` and enable HTTPS after GitHub provisions the certificate.
3. At the DNS provider for `gaz.dev`, create a CNAME record from `nodewatch` to `garylesueur.github.io`.
4. Verify `gaz.dev` in GitHub account Pages settings and retain the TXT verification record.

The Pages workflow deploys the landing page from `site/`. Whenever a GitHub Release is published, it also places that release's signed `appcast.xml` at the permanent feed URL.

## Build a release

Use an integer build number that increases for every release:

```sh
NODEWATCH_VERSION=1.0.0 \
NODEWATCH_BUILD_NUMBER=100 \
NODEWATCH_SIGNING_IDENTITY="Developer ID Application: Example Company (TEAMID)" \
SPARKLE_PUBLIC_KEY="BASE64_PUBLIC_KEY" \
SPARKLE_KEY_ACCOUNT=nodewatch \
NOTARYTOOL_PROFILE=nodewatch-notary \
./scripts/release.sh
```

The script uses the permanent bundle identifier and hosting URLs automatically. Successful output is written beneath `outputs/`, including the app bundle, versioned ZIP, signed appcast, and any Sparkle delta updates.

## Publish a draft

After `make check` and the manual macOS smoke test pass:

```sh
NODEWATCH_VERSION=1.0.0 ./scripts/publish-release.sh
```

This creates a draft GitHub Release at tag `v1.0.0`. Review the attached archive, appcast, delta files, and generated notes. Publishing the draft makes the download public and triggers the Pages deployment.

Before announcing a release, install the ZIP on a clean Mac account and exercise process discovery, browser/Terminal/Finder integration, process termination, and updating from the previous public version.
