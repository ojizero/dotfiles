# view

Unified file viewer — routes to the best tool by file type.

| Extension | Tool |
| :--- | :--- |
| `.md` | `glow` |
| `.json`, `.yml`, `.yaml`, `.toml` | `fx` |
| `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.bmp`, `.svg` | `viu` |
| everything else | `bat` |

## Usage

```
view [OPTIONS] [FILE...]
command | view [OPTIONS]
```

## Flags

| Flag | Format |
| :--- | :--- |
| `-j`, `--json` | JSON (fx) |
| `-m`, `--md` | Markdown (glow) |
| `-y`, `--yaml` | YAML (fx) |
| `-t`, `--toml` | TOML (fx) |
| `-i`, `--image` | Image (viu) |

Flags override extension detection, useful for piped input or misnamed files.

## Suffix aliases

Opening a file by name in zsh (e.g. `./README.md`) routes through `view` for all supported extensions.
