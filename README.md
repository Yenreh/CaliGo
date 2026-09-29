# CaliGo

A Flutter app to check the cards, stops and lines of the MIO, the mass
transit system of Cali, Colombia.

> Unofficial app, not affiliated with Metro Cali S.A. The data comes from
> its public services ([metrocali.gov.co](https://www.metrocali.gov.co))
> and may not be accurate. No commercial purpose.

## Download

Get the APK from the [releases](https://github.com/Yenreh/CaliGo/releases):
`arm64-v8a` for any phone from the last decade, `armeabi-v7a` only for old
32-bit ones. Every release is signed with the same key, so a new one
installs over the previous one and keeps your data. The app can look for a
newer release from Settings > About, on request only.

## Features

- **Cards**: add, edit, reorder and delete transit cards, with the fares
  their balance covers
- **Balance**: from Metrocali's public service, refreshed on opening the
  app (optional)
- **Favorite stops**: the next buses at each saved stop, with the lines to
  show per stop, which ones appear on the home screen, and their order
  saved or by proximity
- **Map**: look up stops anywhere in the city, on CARTO maps, light or dark
- **Lines**: each line's route, its live buses going each way, and its
  hours
- **Trip planner**: from an address, place, stop or point on the map to
  another, timed with the buses on their way
- **Local storage**: everything stays on the device, in SQLite, with JSON
  export and import
- **Languages**: Spanish and English
- **Design**: the "lab report" style shared with NetSpeedDiag and the
  browser extensions, in light and dark themes

## Stack

- **Framework**: Flutter 3.38
- **State management**: Riverpod
- **Database**: SQLite (sqflite)
- **Networking**: http
- **Maps**: flutter_map on CARTO tiles over OpenStreetMap data
- **Location**: geolocator
- **Navigation**: go_router
- **Type**: Fraunces, IBM Plex Sans and IBM Plex Mono, bundled with the app

## Project layout

```
lib/
├── core/                    # Theme, app info, shared utilities
├── data/                    # Data layer
│   ├── datasources/         # Services, database, caches
│   ├── models/              # DTOs
│   └── repositories/        # Implementations
├── domain/                  # Domain layer
│   ├── entities/            # Entities
│   └── repositories/        # Interfaces
├── presentation/            # Presentation layer
│   ├── providers/           # Riverpod providers
│   ├── screens/             # Screens
│   ├── widgets/             # Components
│   └── routes/              # Navigation
├── l10n/                    # Localization
└── main.dart                # Entry point
```

## Building

```bash
flutter pub get
flutter test

# Debug on a device
flutter run --dart-define-from-file=dart_defines.json

# Release APKs, one per ABI
flutter build apk --release --split-per-abi \
  --target-platform android-arm,android-arm64 \
  --dart-define-from-file=dart_defines.json
```

`dart_defines.json` holds the CARTO key and is never committed; copy
`dart_defines.example.json` and fill it in. Without a key the map falls back
to OpenStreetMap tiles.

Release builds are signed with the key described by `key.properties`, never
committed either: `android/key.properties`, which the release workflow
writes from its secrets, or `private/signing/key.properties` next to the key
for local builds. Without one, release builds use the debug key.

## Releases

Changing `VERSION` on `main` builds, signs and publishes a release, with
the notes in `docs/releases/<version>.md` when that file exists. The
workflow needs the `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`,
`KEY_ALIAS` and `CARTO_KEY` secrets, and stops without the signing ones.

## Data

All the data comes from public services of Metro Cali S.A., which allows
reusing its information for informative, non-commercial ends, citing the
source with a link to [metrocali.gov.co](https://www.metrocali.gov.co).
Which services the app reads, and how, is in [docs/api.md](docs/api.md).

## License

CaliGo is free software under the [GNU GPL v3 or later](LICENSE): anyone
may use, study, modify and redistribute it, as long as they keep this
notice and whatever they publish with this code stays free, with its
source available under the same license.

```
CaliGo
Copyright (C) 2026 Yenreh

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
```

The fonts (Fraunces, IBM Plex Sans and Mono) carry their own OFL license,
in `assets/fonts`. Maps © OpenStreetMap contributors and © CARTO; the
transit data belongs to Metro Cali S.A.
