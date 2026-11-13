# Dropify

A Pixeldrain client for Android, built with Flutter.

Dropify is an unofficial, open-source app for managing a Pixeldrain account from
a phone: sign in, upload files, browse folders, and download your content —
without opening a browser.

> **Not affiliated with Pixeldrain.** Pixeldrain is a product of Fornaxian
> Technologies. This project only uses Pixeldrain's public API and is intended
> for managing your own account.

## Features

- **Account** — sign in with username/email and password, including 2FA.
- **Files** — upload, rename, delete, search, sort, and switch between list and
  grid view.
- **Photos** — a dedicated tab for images in your account.
- **Downloads** — queue files, follow live progress in the app and in a
  notification, and keep a history of what you downloaded.
- **Open links** — paste a Pixeldrain link (file, album, folder, or a bare ID)
  and Dropify fetches its details and downloads it.
- **Optional faster mirror** — downloads can be routed through a public mirror
  service instead of the default endpoint. It is a third-party service and can
  be turned off; see *Notes* below.
- **Resumable transfers** — files are fetched in small chunks over several
  connections and continue from the last byte if the connection drops.
- **Saved to `Download/Dropify`** — files land in public storage and open with
  any app on the phone.
- **Interface** — Indonesian and English, system colours (Material You), AMOLED
  black, edge-to-edge layout, predictive back, adaptive launcher icon.

## Requirements

- Android 6.0 (API 23) or newer
- A Pixeldrain account
- Browsing Pixeldrain's folder feature requires a Pixeldrain Pro subscription

## Permissions

| Permission | Why |
| --- | --- |
| `INTERNET` | Pixeldrain API and download endpoints |
| `POST_NOTIFICATIONS` | Progress notifications (Android 13+) |
| `MANAGE_EXTERNAL_STORAGE` | Save directly into `Download/Dropify` (Android 11+) |
| `WRITE_EXTERNAL_STORAGE` | Same, for Android 10 and older |

All-files access is requested on the first download. Without it, Dropify shows
what to enable instead of failing silently.

## Build

```bash
flutter pub get
flutter build apk --release
```

CI (`.github/workflows/build_android.yaml`) builds the APK on every push to
`main`, and attaches it to the GitHub Release when a tag is pushed.

## Project layout

```
lib/
├── l10n/                 # Indonesian + English strings, locale controller
├── models/pd_item.dart   # One Pixeldrain file/folder
├── services/
│   ├── pixeldrain_api.dart    # REST client (login, files, filesystem)
│   ├── pixeldrain_bypass.dart # Optional mirror endpoint builder
│   ├── pd_link.dart           # Parses Pixeldrain links
│   ├── download_service.dart  # Chunked downloader with resume
│   ├── native_downloads.dart  # Method channel bridge (notifications, files)
│   └── app_settings.dart      # Settings and download history
├── screens/              # setup, login, home, files, photos, settings
├── theme/                # Palette, theme, dynamic colour controller
└── widgets/              # Tiles, sheets, progress, animations
```

## Notes

- The optional mirror (`cdn.pixeldrain.eu.cc`) is an independent third-party
  service, not operated by this project and not affiliated with Pixeldrain. If
  it is unavailable, Dropify falls back to the regular Pixeldrain endpoint.
- Downloads are subject to Pixeldrain's own terms and quota. Use the app for
  content you own or are allowed to access.
- Pixeldrain's folder (filesystem) feature is available to Pro accounts only;
  the Files tab explains this for free accounts.

## License

MIT — see [LICENSE](LICENSE).
