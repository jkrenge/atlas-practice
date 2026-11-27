# Notes for agents and contributors

**This repository is public.** Everything committed here, including docs, code comments, commit messages and the history, can be read by anyone and stays in forks forever. Write it that way.

## Never commit

- **Secrets:** API keys, tokens, passwords, certificates, signing identities, provisioning profiles, App Store Connect keys (`.p8`), `.env` files, export or upload option plists, and Xcode export logs (they can hold a live Apple ID session). `.gitignore` covers the usual files; never force-add anything under `build/`.
- **Personal data:** people's names (except credits a data licence requires), email addresses, device names or identifiers, local paths such as `/Users/<name>/`, and account, team or record numbers beyond what `ios/project.yml` already holds.
- **Internal notes:** employer or client details, session or conversation IDs, notes addressed to the owner or to an agent, and transcripts or tool logs.
- **Generated output:** `build/` (including `build/screenshots/`), DerivedData, `.venv/`, `node_modules/`. Only the web copies in `website/assets/screens/` are committed.

Commit with a `users.noreply.github.com` address (`git config user.email`), never a personal or work email.

## Writing docs

Write for a stranger reading the repository: neutral, factual, ISO dates (2026-11-23), and checked against the code and data before you write a number, path or command. Credits must stay in sync in four places: the app's sources screen (`SourcesScreen` in `ios/Atlas/AtlasApp.swift`), `website/credits/`, `NOTICE.md` and `data/SOURCES.md`.

## Where things are

- **App:** `ios/` (SwiftUI, iOS 18+). The Xcode project is generated: `scripts/ios.sh generate`, then `scripts/ios.sh build` or `scripts/ios.sh test SIMULATOR_UDID`. Details in [README.md](README.md).
- **Data:** `scripts/*.py` build `maps/` and `content/` from the pinned snapshots in `data/sources/`; run them with `.venv/bin/python` and check with `scripts/validate_data.py` and `scripts/validate_learning.py`. Formats: [MAP_FORMAT.md](MAP_FORMAT.md); sources: [data/SOURCES.md](data/SOURCES.md).
- **Website:** `website/`, deployed to GitHub Pages by `.github/workflows/pages.yml` on pushes to `main`. Its address also lives in the app (`AtlasLinks`); [website/README.md](website/README.md) lists every place to change together.
- **Screenshots:** `scripts/screenshots.sh` (App Store sizes into `build/screenshots/`, web copies into `website/assets/screens/`).
- **Analytics and crash reports:** [BoringKit](https://github.com/jkrenge/boring-ass-app-kit), started in `AtlasApp.init` and sent to the Worker at `AtlasLinks.api`. Events: `Usage.track`, which honours the Share usage data switch in Settings, with no personal data in props. Unexpected errors: `Aptabase.shared.trackError`. Feedback: `FeedbackView`. Don't add a second crash reporter. When what the app sends changes, change `ios/Atlas/PrivacyInfo.xcprivacy`, `website/privacy/` and the App Store privacy answers together, and publish the website first.
- **Licences:** code under MIT ([LICENSE](LICENSE)); third-party data under its own terms ([NOTICE.md](NOTICE.md)).

## Before you commit

Run the checks that cover what you changed (data validators, unit and UI tests), read `git diff --cached` once with a stranger's eyes, and search it for names, emails, `/Users/` paths and tokens.
