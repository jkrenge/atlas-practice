# Atlas website

The public site for the app: a home page, help and support, the privacy policy, and data credits. Plain HTML and one stylesheet, no build step, no JavaScript, no external fonts, scripts or trackers.

| Page | File | Linked from |
| --- | --- | --- |
| Home | `index.html` | |
| Help and support | `support/index.html` | App: Settings › Help and support |
| Privacy policy | `privacy/index.html` | App: Settings › Privacy policy; App Store Connect |
| Sources and credits | `credits/index.html` | |
| Not found | `404.html` | GitHub Pages, for any missing path |

Styles live in `assets/site.css`. The palette, paper cards, label tape, yellow title tape and picture mats follow the app (`ios/Atlas/MapView.swift`, `ios/Atlas/AtlasCollage.swift`, and `AtlasInk` in `ios/Atlas/AtlasBackdrop.swift`).

## Preview locally

```sh
python3 -m http.server -d website
```

Then open <http://localhost:8000/>. Every internal link is relative, because GitHub Pages serves a project site under a sub-path (`https://<user>.github.io/<repo>/`). The exception is `404.html`: GitHub serves it at whatever path was requested, so it uses one absolute `<base>` instead. Its links and styles therefore point at the live site, and `http.server` doesn't serve it for missing pages anyway.

To test under the Pages sub-path: `mkdir -p build/site-preview && ln -sfn ../../website build/site-preview/atlas-practice && python3 -m http.server 8765 -d build/site-preview`, then open <http://localhost:8765/atlas-practice/>.

## Deploy

`.github/workflows/pages.yml` publishes this folder on every push to `main` that touches `website/**` or the workflow, and on demand from the Actions tab (Run workflow). Once, in the repository settings, set **Pages › Build and deployment › Source** to **GitHub Actions**.

The app links to `https://jkrenge.github.io/atlas-practice/support/` and `.../privacy/` (`AtlasLinks` in `ios/Atlas/AtlasApp.swift`). The same address appears in `index.html` (Open Graph tags), `404.html` (`<base>`), the Website, Privacy and Support links at the top of the repository's `README.md`, and this file. If the repository is renamed or gets a custom domain, change them all together (see Before publishing), and ship an app update before the old address stops working. This README is not deployed: the workflow deletes it before uploading the site.

## Regenerate the pictures

Run on macOS from the repository root. Without arguments, `swift scripts/app_icon.swift` overwrites the app icon, `ios/Atlas/Assets.xcassets/AppIcon.appiconset/AppIcon.png`; `--backdrop` draws the website map instead.

The background map, a 3000 × 1500 view of the North Atlantic drawn from the bundled Natural Earth countries:

```sh
swift scripts/app_icon.swift --backdrop
sips -s format jpeg -s formatOptions 80 website/assets/atlas-map.png --out website/assets/atlas-map.jpg
rm website/assets/atlas-map.png
```

The app screenshots, on fresh iPhone 17 Pro, iPhone 17 Pro Max and iPad Pro 13-inch (M5) simulators (these device types must be installed in Xcode). This writes the App Store sizes to `build/screenshots/` and the web copies (644 × 1400 JPEG) to `website/assets/screens/`. The web copies are made from the Pro Max. The script deletes `build/screenshots/` first.

```sh
scripts/screenshots.sh
```

The page markup expects these eight files with these names: `01-home`, `02-find-the-area`, `03-correct`, `04-flags`, `05-new-york-city`, `06-results`, `07-facts`, `08-settings`. If a capture changes what it shows, update its `alt` text in `index.html`.

`assets/og.jpg` (1200 × 630, the link preview) is a crop of `atlas-map.jpg` with the yellow Atlas tape, made by hand. Redo it if the map changes. `favicon.png`, `apple-touch-icon.png` and `icon-512.png` are scaled copies of the app icon.

## Before publishing

Every undecided value is a visible placeholder: an element with `class="todo"` (shown with a dashed red outline and a "TODO:" prefix) and an HTML comment starting with `TODO(owner):` next to it. Find them all with:

```sh
grep -rn 'TODO(owner)\|class="todo"' website
```

- [ ] **Site address.** For now the site goes live at `jkrenge.github.io/atlas-practice/`, once the repository is public (GitHub Free only serves Pages from public repositories). A custom domain is planned. When it is set, change the address in all six places together: `og:url` and `og:image` in `index.html`, the `<base>` in `404.html` (with a custom domain at the root it becomes `/`), the links at the top of the repository's `README.md`, this README, and `AtlasLinks.site` in `ios/Atlas/AtlasApp.swift`. Do it before an app build with the old address ships, because links inside a shipped build only change with an update.
- [x] **Support contact.** Support runs through GitHub issues (`support/index.html`, Get in touch; `privacy/index.html`, Who we are, If you contact us, Contact). The issue forms are in `.github/ISSUE_TEMPLATE/`. They work once the repository is public.
- [x] **Developer or legal name.** Julian Krenge, on the privacy page (Who we are).
- [x] **German Impressum.** Not included (decided 2026-11-23). If one is needed later, add a Legal notice section to `privacy/index.html` with name, postal address and email, and link it from every footer.
- [ ] **App Store link.** `index.html`, hero notice. Replace the "Coming soon" stamp and paragraph with a link to the App Store page. Use Apple's official badge artwork only as provided, from Apple's marketing resources.
- [ ] **Safari App Store banner** (optional, once live). Uncomment the `apple-itunes-app` meta tag in `index.html` and fill in the app ID.
- [ ] **Screenshots.** Run `scripts/screenshots.sh` on the release build so the pictures match what ships, then check the alt text.
- [ ] **App Store Connect.** Use `…/privacy/` as the Privacy Policy URL and `…/support/` as the Support URL. The App Privacy answers should be "Data Not Collected", matching `ios/Atlas/PrivacyInfo.xcprivacy` and the privacy page.

When the privacy policy changes, update its effective date (currently 2026-11-23).
