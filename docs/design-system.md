# Dropify — sistem desain (Material You)

Aplikasi memakai **Material 3 / M3 Expressive**: semua warna diturunkan dari satu
seed (warna sistem bila "dynamic color" aktif), permukaan tonal, sudut besar, dan
motion berbasis pegas.

## Tampilan

`AppAppearance.light` · `dark` · `amoled` — dipilih di Settings, disimpan di
`ThemeController`, dan status bar ikut menyesuaikan.

## Token (`lib/theme/app_theme.dart`)

`AppColors.scheme` adalah `ColorScheme` M3 aktif — sumber semua warna. Turunan
yang dipakai di layar:

| Token | Peran M3 |
|---|---|
| `bg` | `surface` |
| `card` | `surfaceContainerLow` |
| `cardHigh` | `surfaceContainerHigh` |
| `divider` / `border` | `outlineVariant` |
| `text` | `onSurface` |
| `muted` / `mutedStrong` | `onSurfaceVariant` |
| `primary` / `accent` | `primary` |
| `accentSoft` | `primaryContainer` |
| `danger` | `error` |
| `washA/B/C` | primary/secondary/tertiary (alpha rendah, untuk latar) |

Skala: `AppRadii` 12/16/20/24/28/32/pill · `AppSpace` 6/10/16/22/30 ·
`AppMotion` 180/300/420 ms.

## Komponen (`lib/widgets/kit.dart`)

`AuroraBackground` · `Surface` (tonal, tanpa bayangan default) · `GlassSurface`
(kaca blur, untuk nav & sheet) · `HeroSurface` (tile `primaryContainer`, isi
memakai `onPrimaryContainer`) · `GlowIcon` (kotak ikon tonal) · `OrbIcon`
(empty state) · `PrimaryButton` / `SecondaryButton` · `SoftChip` · `DashedPanel`
· `GlassNav` (nav M3 Expressive: item aktif melebar jadi pill berlabel) ·
`SectionLabel` · `StatRow`.

## Motion (`lib/widgets/motion.dart`)

| Alat | Kegunaan |
|---|---|
| `Motion` + `SpringCurve` | durasi & kurva (emphasized/standard/spring) |
| `Stagger(index:)` | item list/grid masuk bergiliran |
| `Pressable` | press-scale + haptic pada kartu/tombol |
| `AnimatedCount` | angka (ukuran storage, kecepatan) beranimasi |
| `SharedAxisSwitcher` | pergantian konten (loading → isi, filter) |
| `AnimatedIndexedStack` | pindah tab tanpa kehilangan state, tetap beranimasi |
| `SharedAxisPageRoute` | transisi push/pop antar layar |

Aturan: durasi 180–420 ms, kurva dari `Motion`, tidak ada animasi tak berujung
selain wash latar, dan `prefers-reduced-motion` tetap dihormati Flutter.

## Pratinjau

```bash
PREVIEW=1 flutter test test/preview_test.dart --update-goldens
# PNG hasil render ada di test/goldens/
```
