# Theme Customization

v7cms includes a theme system with 40+ configurable CSS properties. Theme settings are managed through the admin Theme tab or programmatically via the API.

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/api/theme` | No | Get current theme settings |
| `PUT` | `/api/theme` | Yes | Update theme (regenerates CSS) |
| `POST` | `/api/theme/reset` | Yes | Reset to defaults |
| `GET` | `/api/theme/preview` | No | Preview with query params |

Updating the theme automatically regenerates `theme.css` and all static HTML files.

## Theme Fields

### Brand Colors

| Field | CSS Variable | Default | Description |
|-------|-------------|---------|-------------|
| `primary_color` | `--color-primary` | `#3b82f6` | Main brand color used for buttons, links, and accents |
| `primary_hover_color` | `--color-primary-hover` | `#2563eb` | Primary color hover state |
| `secondary_color` | `--color-secondary` | `#8b5cf6` | Secondary brand color for accents and highlights |
| `secondary_hover_color` | `--color-secondary-hover` | `#7c3aed` | Secondary color hover state |

### Neutrals

| Field | CSS Variable | Default | Description |
|-------|-------------|---------|-------------|
| `background_color` | `--color-background` | `#ffffff` | Main page background color |
| `surface_color` | `--color-surface` | `#f9fafb` | Cards, panels, and elevated surfaces |
| `surface_hover_color` | `--color-surface-hover` | `#f3f4f6` | Hover state for interactive surfaces |

### Text Hierarchy

| Field | CSS Variable | Default | Description |
|-------|-------------|---------|-------------|
| `text_color` | `--color-text` | `#1f2937` | Primary body text color |
| `text_muted_color` | `--color-text-muted` | `#6b7280` | Secondary text, captions, metadata |
| `text_subtle_color` | `--color-text-subtle` | `#9ca3af` | Tertiary text, placeholders, disabled states |
| `heading_color` | `--color-heading` | `#111827` | Headings (h1, h2, h3, etc.) |

### Interactive

| Field | CSS Variable | Default | Description |
|-------|-------------|---------|-------------|
| `link_color` | `--color-link` | `#2563eb` | Hyperlink color |
| `link_hover_color` | `--color-link-hover` | `#1d4ed8` | Hyperlink hover state |
| `link_visited_color` | `--color-link-visited` | `#7c3aed` | Visited link color |

### UI States

| Field | CSS Variable | Default | Description |
|-------|-------------|---------|-------------|
| `border_color` | `--color-border` | `#e5e7eb` | Default border color |
| `border_strong_color` | `--color-border-strong` | `#d1d5db` | Emphasized borders, dividers |
| `focus_color` | `--color-focus` | `#3b82f6` | Focus ring color for keyboard navigation |
| `success_color` | `--color-success` | `#10b981` | Success messages, positive states |
| `warning_color` | `--color-warning` | `#f59e0b` | Warning messages, cautionary states |
| `error_color` | `--color-error` | `#ef4444` | Error messages, destructive actions |
| `info_color` | `--color-info` | `#06b6d4` | Informational messages, tooltips |

### Typography

| Field | CSS Variable | Type | Default | Description |
|-------|-------------|------|---------|-------------|
| `font_heading` | `--font-heading` | string | `system-ui, -apple-system, sans-serif` | Font family for headings |
| `font_body` | `--font-body` | string | `system-ui, -apple-system, sans-serif` | Font family for body text |
| `font_mono` | `--font-mono` | string | `ui-monospace, monospace` | Font family for code blocks |
| `font_size_base` | `--font-size-base` | integer (px) | `16` | Base font size in pixels (12-24) |
| `line_height_base` | `--line-height-base` | decimal | `1.6` | Default line height for body text (1.0-2.5) |
| `line_height_tight` | `--line-height-tight` | decimal | `1.25` | Tight line height for headings (1.0-2.5) |
| `line_height_loose` | `--line-height-loose` | decimal | `1.75` | Loose line height for readability (1.0-2.5) |

### Layout & Spacing

| Field | CSS Variable | Type | Default | Description |
|-------|-------------|------|---------|-------------|
| `layout_width` | `--container-max` | enum | `standard` | Maximum container width: `narrow` (900px), `standard` (1200px), `wide` (1400px), `full` (100%) |
| `spacing_unit` | `--spacing-unit` | decimal (rem) | `1.0` | Base spacing scale (0.25-10.0 rem) |
| `spacing_section` | `--spacing-section` | decimal (rem) | `4.0` | Spacing between major sections (0.25-10.0 rem) |

### Effects

| Field | CSS Variable | Type | Default | Description |
|-------|-------------|------|---------|-------------|
| `radius_sm` | `--radius-sm` | string | `4px` | Border radius for small elements |
| `radius_default` | `--radius-default` | string | `8px` | Default border radius |
| `radius_lg` | `--radius-lg` | string | `16px` | Border radius for large elements |
| `border_width` | `--border-width` | string | `1px` | Default border width |
| `shadow_sm` | `--shadow-sm` | text | `0 1px 2px 0 rgb(0 0 0 / 0.05)` | Subtle shadow for slight elevation |
| `shadow_default` | `--shadow-default` | text | `0 1px 3px 0 rgb(0 0 0 / 0.1)` | Default shadow for cards and panels |
| `shadow_lg` | `--shadow-lg` | text | `0 10px 15px -3px rgb(0 0 0 / 0.1)` | Prominent shadow for modals and overlays |

### Advanced

| Field | CSS Variable | Type | Default | Description |
|-------|-------------|------|---------|-------------|
| `header_style` | — | enum | `default` | Header appearance: `default`, `minimal`, `prominent` |
| `footer_style` | — | enum | `default` | Footer appearance: `default`, `minimal`, `centered` |
| `custom_css` | — | text | (empty) | Additional custom CSS rules (max 10,000 characters) |

`header_style` and `footer_style` are applied via template logic rather than CSS variables. `custom_css` is injected directly into the generated theme stylesheet.

## Validation Rules

- **Color fields**: Must be valid hex colors (`#RGB` or `#RRGGBB`)
- **font_size_base**: Integer, 12-24
- **line_height_***: Decimal, 1.0-2.5
- **spacing_unit, spacing_section**: Decimal, 0.25-10.0
- **layout_width**: One of `narrow`, `standard`, `wide`, `full`
- **header_style**: One of `default`, `minimal`, `prominent`
- **footer_style**: One of `default`, `minimal`, `centered`
- **Font families**: Max 200 characters
- **Radius/border strings**: Max 20 characters
- **Shadow strings**: Max 500 characters
- **custom_css**: Max 10,000 characters

## How It Works

The theme is a singleton ActiveRecord model (`V7CMS::Theme`). When updated, two callbacks fire:

1. **`regenerate_theme_css`** — `ThemeGenerator` reads all field values, maps them to CSS variables using `ThemeConfig::FIELDS`, and writes `public/css/theme.css`
2. **`regenerate_all_static_files`** — re-renders all published posts and pages to static HTML so they pick up the new theme

Field definitions live in `ThemeConfig::FIELDS` (`lib/v7cms/config/theme_fields.rb`), which serves as the single source of truth for database columns, validations, CSS variable mapping, and admin UI rendering.
