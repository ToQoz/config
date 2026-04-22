# Android emulator device profile reference

`avdmanager list device` only returns id / name / OEM / tag — not screen
dimensions or density. This file pins the dimensions for the modern
Pixel-family profiles so a preset can pick a target device deliberately
without re-probing every time.

## Recommendation

Pick by CSS-px viewport width (the lever that decides whether a layout
will reflow / clip):

| Bucket | CSS-px width | Devices | When to use |
|---|---|---|---|
| **Default** (modern mid-range) | ~411 | pixel_6 / 7 / 8 / 9 and their _a variants, medium_phone | Most realistic baseline for current Android users — choose this for new presets unless there is a reason not to. |
| **Conservative narrow** | ~393 | pixel_4a (current LINE MiniApp preset), pixel_5 | Slightly narrower viewport surfaces fixed-width / overflow bugs earlier. Keep using when an existing preset is calibrated against it. |
| **Pro / XL** | ~427 – 448 | pixel_8_pro, pixel_9_pro, pixel_9_pro_xl | Only for explicit large-screen verification; not representative of typical users. |
| **Foldables / tablets / Pro-fold** | varies | pixel_9_pro_fold, pixel_fold, pixel_tablet, pixel_c | Out of scope for typical mini-app a11y; needs its own preset. |

Density figures here are the **base** density. The skill's a11y preset
multiplies it (`apply_a11y.sh --density-multiplier`) to mimic Android's
"Display Size" lever, which reflows the layout into a still narrower CSS
viewport.

## Data (Pixel family + medium_phone)

| Device id | Resolution (px) | Base density | CSS-px width |
|---|---|---|---|
| `pixel_4a`        | 1080 × 2340 | 440 dpi | 393 |
| `pixel_5`         | 1080 × 2340 | 440 dpi | 393 |
| `pixel_6`         | 1080 × 2400 | 420 dpi | 411 |
| `pixel_6_pro`     | 1440 × 3120 | 560 dpi | 411 |
| `pixel_6a`        | 1080 × 2400 | 420 dpi | 411 |
| `pixel_7`         | 1080 × 2400 | 420 dpi | 411 |
| `pixel_7_pro`     | 1440 × 3120 | 560 dpi | 411 |
| `pixel_7a`        | 1080 × 2400 | 420 dpi | 411 |
| `pixel_8`         | 1080 × 2400 | 420 dpi | 411 |
| `pixel_8_pro`     | 1344 × 2992 | 480 dpi | 448 |
| `pixel_8a`        | 1080 × 2400 | 420 dpi | 411 |
| `pixel_9`         | 1080 × 2424 | 420 dpi | 411 |
| `pixel_9_pro`     | 1280 × 2856 | 480 dpi | 427 |
| `pixel_9_pro_xl`  | 1344 × 2992 | 480 dpi | 448 |
| `pixel_9a`        | 1080 × 2424 | 420 dpi | 411 |
| `medium_phone`    | 1080 × 2400 | 420 dpi | 411 |

CSS-px width = `hw.lcd.width / (hw.lcd.density / 160)`, rounded.

## How this table was produced

`avdmanager list device` does not include dimensions. The values above
were captured locally by creating a throwaway AVD per device profile
and reading `~/.android/avd/<name>.avd/config.ini`:

```bash
source scripts/sdkenv.sh
for d in pixel_4a pixel_5 pixel_6 pixel_6_pro pixel_6a \
         pixel_7 pixel_7_pro pixel_7a \
         pixel_8 pixel_8_pro pixel_8a \
         pixel_9 pixel_9_pro pixel_9_pro_xl pixel_9a \
         medium_phone; do
  echo no | avdmanager create avd \
    -n "probe-$d" \
    -k "system-images;android-36;google_apis_playstore;arm64-v8a" \
    -d "$d" >/dev/null 2>&1
  awk -F= -v d="$d" '
    /^hw.lcd.width=/   { w=$2 }
    /^hw.lcd.height=/  { h=$2 }
    /^hw.lcd.density=/ { p=$2 }
    END { printf "%-16s %sx%s @ %s dpi\n", d, w, h, p }
  ' "$HOME/.android/avd/probe-$d.avd/config.ini"
  avdmanager delete avd -n "probe-$d" >/dev/null 2>&1
done
```

When a new SDK release adds device ids (or AVD-default dimensions
change), re-run the loop and update the table.

A web search against device spec sheets is a viable alternative when
the SDK is not handy, but the AVD-default values can differ slightly
from the marketing spec (the AVD pixel_4a, for example, reports
`1080×2340 @ 440 dpi` — close to but not exactly the real Pixel 4a).
The AVD value is what actually drives the emulator, so prefer the
local probe.
