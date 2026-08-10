# Distributing NodeWatch

NodeWatch is designed for direct distribution from a website. A production release is:

1. built as a universal Apple Silicon/Intel application;
2. signed with a Developer ID Application certificate and the hardened runtime;
3. notarized and stapled by Apple;
4. zipped for download; and
5. signed and added to a Sparkle appcast for automatic updates.

Both update archives and the appcast are EdDSA-verified before NodeWatch presents or extracts an update.

## One-time setup

1. Join the Apple Developer Program and install a `Developer ID Application` certificate in the login keychain.
2. Store notarization credentials in the keychain:

   ```sh
   xcrun notarytool store-credentials nodewatch-notary \
     --apple-id "you@example.com" \
     --team-id "YOUR_TEAM_ID" \
     --password "APP_SPECIFIC_PASSWORD"
   ```

3. Generate a Sparkle EdDSA key. The private key remains in Keychain; keep an encrypted backup and do not put it on the website server:

   ```sh
   .build/artifacts/sparkle/Sparkle/bin/generate_keys --account nodewatch
   ```

4. Choose permanent HTTPS locations, for example:

   - `https://example.com/downloads/nodewatch/appcast.xml`
   - `https://example.com/downloads/nodewatch/NodeWatch-1.0.0.zip`

The bundle identifier must also be permanent before the first public release. Use a reverse-DNS identifier owned by the publisher.

## Create a release

Use an integer build number that increases for every release, even if the marketing version changes:

```sh
NODEWATCH_VERSION=1.0.0 \
NODEWATCH_BUILD_NUMBER=100 \
NODEWATCH_BUNDLE_ID=com.example.nodewatch \
NODEWATCH_SIGNING_IDENTITY="Developer ID Application: Example Company (TEAMID)" \
SPARKLE_FEED_URL="https://example.com/downloads/nodewatch/appcast.xml" \
SPARKLE_PUBLIC_KEY="BASE64_PUBLIC_KEY" \
SPARKLE_DOWNLOAD_URL_PREFIX="https://example.com/downloads/nodewatch/" \
SPARKLE_KEY_ACCOUNT=nodewatch \
NOTARYTOOL_PROFILE=nodewatch-notary \
./scripts/release.sh
```

Upload the contents of `outputs/updates/` to the matching website directory. Keep old archives in that directory while generating later appcasts so Sparkle can create efficient delta updates.

Sparkle asks the user on the second launch whether NodeWatch may check automatically and whether updates may download automatically. Manual checks are always available from the app menu, menu-bar panel, and Settings.

Before publishing, install the zip on a clean Mac user account and exercise process discovery, opening projects, stopping a process, and an update from the previous public version.

## Sign-in

Sign-in is not required for installation or automatic updates. Add it only when NodeWatch has an account-backed feature such as paid entitlement, synced settings, or team functionality.

For a native macOS app, use the system browser with OAuth 2.0 Authorization Code + PKCE, return through a registered callback URL, exchange the one-time code on the backend, and store only short-lived access/refresh tokens in Keychain. Do not embed a client secret in the app. The implementation needs three product choices before it should be wired in:

- the identity provider;
- the production API and callback domains; and
- what a signed-in account unlocks.

Authentication should not gate process monitoring unless that is an intentional licensing decision. Keep the app useful offline and degrade account-backed features independently when the API is unavailable.
