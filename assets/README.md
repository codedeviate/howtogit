# Brand assets

The `$ how to git` title lockup from the book covers, for reuse elsewhere
(README hero, docs, slides, social).

| File | Use |
|------|-----|
| `howtogit-title.svg` | **Primary.** Outlined (text → paths), so it renders identically everywhere even without the Menlo / SF Mono font. For light backgrounds. |
| `howtogit-title-dark.svg` | Same, for dark backgrounds ("how to" is near-white). |
| `howtogit-title.png` | Raster fallback (1450×256, transparent, light backgrounds) for places that don't accept SVG. |
| `howtogit-title.src.svg` | Editable source (real `<text>`, font-dependent). Edit this, then re-outline. |
| `howtogit-title-dark.src.svg` | Editable dark source. |

Colors: `$` grey `#8a8a8a`, "how to" `#1a1a1a` (light) / `#e6e6e6` (dark),
"git" + cursor git-orange `#f05033`. Font: bold monospace (SF Mono / Menlo).

## Regenerating

Edit a `.src.svg`, then outline it to the portable version with Inkscape:

```sh
inkscape howtogit-title.src.svg --export-type=svg --export-text-to-path \
  --export-plain-svg --export-filename=howtogit-title.svg
# raster:
inkscape howtogit-title.svg --export-type=png --export-filename=howtogit-title.png -w 1450
```
