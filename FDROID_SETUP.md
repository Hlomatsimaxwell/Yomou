# F-Droid personal repository (Option B)

Yomou publishes to a personal F-Droid repository via the
`.github/workflows/fdroid.yml` workflow, triggered on every `v*` tag push or
manual dispatch. Users add the repo URL in their F-Droid client:

```
https://raw.githubusercontent.com/Hlomatsimaxwell/fdroid-repo/main/repo/
```

## One-time setup

1. **License** — done. The project is Apache-2.0 (see `LICENSE` and
   `pubspec.yaml`'s `license:` field).
2. **Create the published repo** — make a *public* GitHub repo named
   `fdroid-repo` (change `FDROID_REPO` in the workflow if you rename it).
3. **Generate the repo signing key (once).** F-Droid clients trust the key the
   index is signed with, so it must stay stable across builds:
   ```
   sudo apt-get install fdroidserver
   mkdir -p /tmp/fdroid && cd /tmp/fdroid
   fdroid init        # generates keystore.p12 + config.yml
   tar -czf fdroid-key.tar.gz .
   base64 -w0 fdroid-key.tar.gz > fdroid-key.b64
   ```
   Store the contents of `fdroid-key.b64` as the repo secret
   `FDROID_REPO_KEYSTORE_BASE64`.
4. **Add PAT secret** `FDROID_REPO_PAT`: a fine-grained token with
   `contents: write` on the `fdroid-repo` repository.
5. **(Optional) metadata** — `fastlane/metadata/android/en-US/` holds the
   listing (title/short/full description). Screenshots can be added under
   `images/phoneScreenshots/`.

## How it works

- On a `v*` tag push, the workflow builds the release APK, decodes the stored
  signing key (or bootstraps a new one on the first run and uploads it as an
  artifact — save it as the secret!), runs `fdroid update` to build the index,
  and pushes the `repo/` contents to `fdroid-repo`.

On the first run **save the uploaded `fdroid-repo-state` artifact** and turn it
into the `FDROID_REPO_KEYSTORE_BASE64` secret, otherwise later runs will sign
with a different key and F-Droid clients will reject the update.

## Notes

- `fastlane/metadata` is also what the official F-Droid main repo would read if
  you later submit an MR to `fdroid/fdroiddata` (Option A). Keeping it in the
  repo now means no rework later.
- The app's own in-app update check (GitHub Releases) continues to work
  alongside this; F-Droid users simply use F-Droid as their update channel.