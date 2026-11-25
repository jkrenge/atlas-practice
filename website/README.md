# Atlas website

The public site for the app: a home page, help and support, the privacy policy, and data credits. Plain HTML and one stylesheet, no build step, no JavaScript, no external fonts, scripts or trackers.

| Page | File | Linked from |
| --- | --- | --- |
| Home | `index.html` | |
| Help and support | `support/index.html` | App: Settings › Help and support |
| Privacy policy | `privacy/index.html` | App: Settings › Privacy policy; App Store Connect |
| Sources and credits | `credits/index.html` | |
| Not found | `404.html` | GitHub Pages, for any missing path |

Styles live in `assets/site.css`; the light gray phone frames around the screenshots are drawn there too, with no image. The palette, paper cards, label tape and yellow title tape follow the app (`ios/Atlas/MapView.swift`, `ios/Atlas/AtlasCollage.swift`, and `AtlasInk` in `ios/Atlas/AtlasBackdrop.swift`).

## Preview locally

```sh
python3 -m http.server -d website
```

Then open <http://localhost:8000/>. Internal links are relative, so the pages also work under a sub-path. The exception is `404.html`: GitHub serves it at whatever path was requested, so it uses `<base href="/">`, which assumes the site sits at the root of its domain. `http.server` doesn't serve it for missing pages; open <http://localhost:8000/404.html> to see it.

## Deploy

`.github/workflows/pages.yml` publishes this folder on every push to `main` that touches `website/**` or the workflow, and on demand from the Actions tab (Run workflow). Once, in the repository settings, set **Pages › Build and deployment › Source** to **GitHub Actions**.

The app links to `https://atlas-practice.app/support/` and `.../privacy/` (`AtlasLinks` in `ios/Atlas/AtlasApp.swift`). The same address appears in `index.html` (Open Graph tags), the Website, Privacy and Support links at the top of the repository's `README.md`, the help link in `.github/ISSUE_TEMPLATE/config.yml`, and this file; `404.html` relies on it being the root of the domain. Outside the files, it is also set in **Settings › Pages › Custom domain**, the repository's About › Website field, and App Store Connect (Privacy Policy and Support URLs). If the domain changes, change them all together, and ship an app update before the old address stops working, because links inside a shipped build only change with an update. This README is not deployed: the workflow deletes it before uploading the site.

### Custom domain

The site is served at `https://atlas-practice.app/`. Because it deploys from a GitHub Actions workflow, the domain is set in **Settings › Pages › Custom domain**; a `CNAME` file in this folder would be ignored. The setup, in the order GitHub recommends ([GitHub docs](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site)):

1. Verify the domain for the account that owns the repository (account **Settings › Pages › Add a domain**). GitHub shows a TXT record for `_github-pages-challenge-<user>.<domain>`. Keep it in DNS for as long as the domain is in use.
2. Enter the domain under **Settings › Pages › Custom domain** in this repository.
3. At the DNS provider, replace the provider's default records for the apex and `www`:
   - apex: `A` 185.199.108.153, 185.199.109.153, 185.199.110.153 and 185.199.111.153; `AAAA` 2606:50c0:8000::153, 2606:50c0:8001::153, 2606:50c0:8002::153 and 2606:50c0:8003::153;
   - `www`: `CNAME` to `<user>.github.io`, without the repository name. GitHub then redirects `www` to the apex.

   Don't point a wildcard record at GitHub Pages. Don't put a proxy or CDN in front either: the privacy policy says GitHub Pages serves every file.
4. Once GitHub has issued the certificate, tick **Enforce HTTPS**. `.app` is on the HSTS preload list, so browsers only load the site over HTTPS, and it is unreachable until the certificate exists.

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

- [x] **Site address.** `https://atlas-practice.app/` (see Custom domain under Deploy).
- [x] **Support contact.** Support runs through GitHub issues (`support/index.html`, Get in touch; `privacy/index.html`, Who we are, If you contact us, Contact). The issue forms are in `.github/ISSUE_TEMPLATE/`. They work once the repository is public.
- [x] **Developer or legal name.** Julian Krenge, on the privacy page (Who we are).
- [x] **German Impressum.** Not included (decided 2026-11-23). If one is needed later, add a Legal notice section to `privacy/index.html` with name, postal address and email, and link it from every footer.
- [ ] **App Store link.** `index.html`, hero notice. Replace the "Coming soon" stamp and paragraph with a link to the App Store page. Use Apple's official badge artwork only as provided, from Apple's marketing resources.
- [ ] **Safari App Store banner** (optional, once live). Uncomment the `apple-itunes-app` meta tag in `index.html` and fill in the app ID.
- [x] **Screenshots.** Retaken for 1.0 (2) on 2026-11-25 with `scripts/screenshots.sh`; alt text checked. Run it again after any visible change so the pictures match what ships.
- [ ] **App Store Connect.** Use `https://atlas-practice.app/privacy/` as the Privacy Policy URL and `https://atlas-practice.app/support/` as the Support URL. The App Privacy answers should be "Data Not Collected", matching `ios/Atlas/PrivacyInfo.xcprivacy` and the privacy page.

When the privacy policy changes, update its effective date (currently 2026-11-23).
