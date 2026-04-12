---
name: web-image-compression
description: Recommend and execute image compression/conversion pipelines for web delivery, using Nix (`nix run`) so nothing needs to be installed globally. Use this skill whenever the user wants to optimize images for the web, reduce image file sizes, convert between image formats (PNG, JPEG, WebP, AVIF, SVG), or set up an image processing pipeline — even if they don't explicitly say "compress".
---

## Overview

This skill helps you build image optimization pipelines for web delivery. Every command runs via `nix run nixpkgs#<package>` so the user's system stays clean — no global installs required.

## Decision Flow

When the user asks to optimize images, walk through these questions:

1. **What format is the source?** (PNG, JPEG, SVG, or mixed)
2. **Is transparency needed?** (rules out JPEG)
3. **Is the image photographic or graphic/illustration?** (affects format choice and quality settings)
4. **Should we convert to a modern format (WebP)?** (default: yes for raster, unless the user needs maximum compatibility)
5. **Does the user want AVIF?** Only use AVIF if explicitly requested — browser support is still incomplete.
6. **What's the target use case?** (hero image, thumbnail, icon, sprite sheet — affects dimensions and quality)

### Format Selection Guide

| Source | Transparency? | Content Type | Recommendation |
|--------|--------------|--------------|----------------|
| PNG | No | Photo | Convert to WebP (or JPEG fallback) |
| PNG | Yes | Photo | WebP with alpha, or optimize PNG |
| PNG | Yes | Graphic/UI | Optimize with pngquant + oxipng |
| PNG | No | Graphic/UI | WebP or optimized PNG |
| JPEG | N/A | Photo | jpegoptim, optionally also produce WebP |
| SVG | N/A | Vector | svgo |

When producing WebP, always keep the optimized original as a fallback for `<picture>` elements.

## Tools and Commands

All commands use `nix run` — no installation needed. The user can copy-paste these directly.

### PNG Lossless Optimization — oxipng

Reduces file size without any quality loss by optimizing compression parameters.

```bash
nix run nixpkgs#oxipng -- -o 4 -i 0 --out out.png in.png
```

- `-o 4`: optimization level (0=fast, 6=slowest/smallest). 4 is a good balance.
- `-i 0`: remove interlacing (smaller files, better for web)
- `--out`: output path. Without it, oxipng overwrites the input.

### PNG Lossy Quantization — pngquant

Reduces colors to shrink file size significantly (often 60-80% reduction). Best for graphics, icons, and illustrations.

```bash
nix run nixpkgs#pngquant -- --quality=70-90 --strip --output out.png in.png
```

- `--quality=MIN-MAX`: pngquant will abort if it can't achieve at least MIN quality. Use `65-85` for smaller files, `80-95` for higher quality.
- `--strip`: remove metadata chunks.
- Combine with oxipng for maximum savings: quantize first, then run oxipng on the result.

### JPEG Optimization — jpegoptim

Strips metadata and optionally recompresses. Modifies files in place by default.

```bash
# In-place optimization (copies input first)
cp in.jpg out.jpg && nix run nixpkgs#jpegoptim -- --strip-all --max=85 out.jpg
```

```bash
# Output to a directory
mkdir -p optimized && nix run nixpkgs#jpegoptim -- --strip-all --max=85 --dest=optimized in.jpg
```

- `--max=85`: cap quality at 85. Use 80-85 for web photos, 90+ for hero/banner images.
- `--strip-all`: remove all metadata (EXIF, comments, etc.).
- jpegoptim has no `--output` flag — use `--dest=<dir>` or copy-then-optimize.

### WebP Conversion — cwebp

WebP typically achieves 25-35% smaller files than equivalent JPEG/PNG.

```bash
nix run nixpkgs#libwebp -- cwebp -q 80 in.png -o out.webp
```

```bash
# Lossless WebP (for graphics/icons where quality is critical)
nix run nixpkgs#libwebp -- cwebp -lossless in.png -o out.webp
```

- `-q 80`: quality 0-100. Use 75-80 for photos, 85-90 for high-quality needs.
- `-lossless`: lossless mode. Good for graphics, often larger than lossy for photos.
- `-resize W H`: resize during conversion (use 0 for one dimension to maintain aspect ratio).

### AVIF Conversion — avifenc

Only recommend when the user explicitly asks for AVIF. AVIF offers better compression than WebP but has incomplete browser support (no IE, limited older Safari).

```bash
nix run nixpkgs#libavif -- avifenc --min 20 --max 35 -s 6 in.png out.avif
```

- `--min/--max`: quality range (0=best, 63=worst). 20-35 is a good range for web.
- `-s 6`: speed (0=slowest/best, 10=fastest). 6 balances speed and quality.

### SVG Optimization — svgo

Removes unnecessary metadata, comments, and redundant attributes from SVGs.

```bash
nix run nixpkgs#nodePackages.svgo -- svgo in.svg -o out.svg
```

```bash
# Process a directory
nix run nixpkgs#nodePackages.svgo -- svgo -f ./svg-input -o ./svg-output
```

**Caution:** svgo can occasionally alter rendering, especially with complex SVGs that use filters, masks, or specific attribute ordering. Always compare before/after visually. If the output looks wrong, try a custom config to disable aggressive plugins:

```bash
nix run nixpkgs#nodePackages.svgo -- svgo --config '{"plugins": [{"name": "preset-default", "params": {"overrides": {"removeViewBox": false, "cleanupIds": false}}}]}' in.svg -o out.svg
```

### Resizing with ImageMagick

For generating responsive variants or thumbnails:

```bash
# Resize to specific width, maintain aspect ratio
nix run nixpkgs#imagemagick -- magick in.png -resize 800x out.png

# Generate multiple sizes for responsive images
for w in 480 768 1024 1920; do
  nix run nixpkgs#imagemagick -- magick in.png -resize "${w}x" "out-${w}w.png"
done
```

## Common Pipelines

### Photo optimization (JPEG source)

```bash
# 1. Optimize the JPEG
cp photo.jpg optimized.jpg
nix run nixpkgs#jpegoptim -- --strip-all --max=82 optimized.jpg

# 2. Create WebP variant
nix run nixpkgs#libwebp -- cwebp -q 78 photo.jpg -o photo.webp
```

Then use in HTML:
```html
<picture>
  <source srcset="photo.webp" type="image/webp">
  <img src="optimized.jpg" alt="..." loading="lazy" decoding="async">
</picture>
```

### PNG graphic optimization

```bash
# 1. Quantize
nix run nixpkgs#pngquant -- --quality=70-90 --strip --output quantized.png graphic.png

# 2. Lossless-optimize the quantized result
nix run nixpkgs#oxipng -- -o 4 -i 0 --out optimized.png quantized.png

# 3. Also create WebP
nix run nixpkgs#libwebp -- cwebp -q 80 graphic.png -o graphic.webp
```

### Batch processing

```bash
# Optimize all JPEGs in a directory
mkdir -p optimized
for f in *.jpg; do
  cp "$f" "optimized/$f"
  nix run nixpkgs#jpegoptim -- --strip-all --max=82 "optimized/$f"
  nix run nixpkgs#libwebp -- cwebp -q 78 "$f" -o "optimized/${f%.jpg}.webp"
done
```

### Responsive image set

```bash
src="hero.png"
for w in 480 768 1280 1920; do
  nix run nixpkgs#imagemagick -- magick "$src" -resize "${w}x" "hero-${w}w.png"
  nix run nixpkgs#libwebp -- cwebp -q 80 "hero-${w}w.png" -o "hero-${w}w.webp"
done
```

## Quality Guidelines

These are starting points — always adjust based on visual inspection:

| Use Case | JPEG max | WebP -q | pngquant range |
|----------|---------|---------|----------------|
| Hero/banner | 88-92 | 85-90 | 85-95 |
| Content photo | 80-85 | 75-80 | — |
| Thumbnail | 75-80 | 70-75 | — |
| UI graphic/icon | — | 80-85 (or lossless) | 70-90 |
| Screenshot | — | 80 (or lossless) | 75-90 |

## Verification

After optimization, always report the before/after file sizes so the user can see the savings:

```bash
# Quick size comparison
ls -lh in.png out.png out.webp
```

If the user wants to verify visual quality, suggest opening both files side by side, or use ImageMagick to compute the difference:

```bash
nix run nixpkgs#imagemagick -- magick compare -metric SSIM in.png out.png diff.png
```

## Key Reminders

- Always keep the optimized original format as a fallback — not all browsers support WebP.
- Do not produce AVIF unless the user explicitly requests it.
- For `<picture>` elements, list sources from most-compressed to least (WebP first, then fallback).
- Add `loading="lazy"` and `decoding="async"` to `<img>` tags for below-the-fold images.
- Strip metadata (`--strip`, `--strip-all`) — EXIF data can add significant weight and may leak location info.
