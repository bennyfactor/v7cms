# frozen_string_literal: true

# Centralized theme field configuration
# Single source of truth for database schema, validations, CSS generation, and admin UI
module ThemeConfig
  # All theme fields with metadata
  # Format: field_name => { css_var, default, type, [suffix], [transform], [values] }
  FIELDS = {
    # ===== Brand Colors =====
    primary_color: {
      css_var: '--color-primary',
      default: '#3b82f6',
      type: :color,
      label: 'Primary Color',
      description: 'Main brand color used for buttons, links, and accents'
    },
    primary_hover_color: {
      css_var: '--color-primary-hover',
      default: '#2563eb',
      type: :color,
      label: 'Primary Hover',
      description: 'Primary color hover state'
    },
    secondary_color: {
      css_var: '--color-secondary',
      default: '#8b5cf6',
      type: :color,
      label: 'Secondary Color',
      description: 'Secondary brand color for accents and highlights'
    },
    secondary_hover_color: {
      css_var: '--color-secondary-hover',
      default: '#7c3aed',
      type: :color,
      label: 'Secondary Hover',
      description: 'Secondary color hover state'
    },

    # ===== Neutrals =====
    background_color: {
      css_var: '--color-background',
      default: '#ffffff',
      type: :color,
      label: 'Background',
      description: 'Main page background color'
    },
    surface_color: {
      css_var: '--color-surface',
      default: '#f9fafb',
      type: :color,
      label: 'Surface',
      description: 'Cards, panels, and elevated surfaces'
    },
    surface_hover_color: {
      css_var: '--color-surface-hover',
      default: '#f3f4f6',
      type: :color,
      label: 'Surface Hover',
      description: 'Hover state for interactive surfaces'
    },

    # ===== Text Hierarchy =====
    text_color: {
      css_var: '--color-text',
      default: '#1f2937',
      type: :color,
      label: 'Text',
      description: 'Primary body text color'
    },
    text_muted_color: {
      css_var: '--color-text-muted',
      default: '#6b7280',
      type: :color,
      label: 'Text Muted',
      description: 'Secondary text, captions, metadata'
    },
    text_subtle_color: {
      css_var: '--color-text-subtle',
      default: '#9ca3af',
      type: :color,
      label: 'Text Subtle',
      description: 'Tertiary text, placeholders, disabled states'
    },
    heading_color: {
      css_var: '--color-heading',
      default: '#111827',
      type: :color,
      label: 'Heading',
      description: 'Headings (h1, h2, h3, etc.)'
    },

    # ===== Interactive =====
    link_color: {
      css_var: '--color-link',
      default: '#2563eb',
      type: :color,
      label: 'Link',
      description: 'Hyperlink color'
    },
    link_hover_color: {
      css_var: '--color-link-hover',
      default: '#1d4ed8',
      type: :color,
      label: 'Link Hover',
      description: 'Hyperlink hover state'
    },
    link_visited_color: {
      css_var: '--color-link-visited',
      default: '#7c3aed',
      type: :color,
      label: 'Link Visited',
      description: 'Visited link color'
    },

    # ===== UI States =====
    border_color: {
      css_var: '--color-border',
      default: '#e5e7eb',
      type: :color,
      label: 'Border',
      description: 'Default border color'
    },
    border_strong_color: {
      css_var: '--color-border-strong',
      default: '#d1d5db',
      type: :color,
      label: 'Border Strong',
      description: 'Emphasized borders, dividers'
    },
    focus_color: {
      css_var: '--color-focus',
      default: '#3b82f6',
      type: :color,
      label: 'Focus',
      description: 'Focus ring color for keyboard navigation'
    },
    success_color: {
      css_var: '--color-success',
      default: '#10b981',
      type: :color,
      label: 'Success',
      description: 'Success messages, positive states'
    },
    warning_color: {
      css_var: '--color-warning',
      default: '#f59e0b',
      type: :color,
      label: 'Warning',
      description: 'Warning messages, cautionary states'
    },
    error_color: {
      css_var: '--color-error',
      default: '#ef4444',
      type: :color,
      label: 'Error',
      description: 'Error messages, destructive actions'
    },
    info_color: {
      css_var: '--color-info',
      default: '#06b6d4',
      type: :color,
      label: 'Info',
      description: 'Informational messages, tooltips'
    },

    # ===== Typography =====
    font_heading: {
      css_var: '--font-heading',
      default: 'system-ui, -apple-system, sans-serif',
      type: :string,
      label: 'Heading Font',
      description: 'Font family for headings'
    },
    font_body: {
      css_var: '--font-body',
      default: 'system-ui, -apple-system, sans-serif',
      type: :string,
      label: 'Body Font',
      description: 'Font family for body text'
    },
    font_mono: {
      css_var: '--font-mono',
      default: 'ui-monospace, monospace',
      type: :string,
      label: 'Monospace Font',
      description: 'Font family for code blocks'
    },
    font_size_base: {
      css_var: '--font-size-base',
      default: 16,
      type: :integer,
      suffix: 'px',
      label: 'Base Font Size',
      description: 'Base font size in pixels (14-20 recommended)'
    },
    line_height_base: {
      css_var: '--line-height-base',
      default: 1.6,
      type: :decimal,
      label: 'Base Line Height',
      description: 'Default line height for body text (1.4-1.8)'
    },
    line_height_tight: {
      css_var: '--line-height-tight',
      default: 1.25,
      type: :decimal,
      label: 'Tight Line Height',
      description: 'Tight line height for headings (1.1-1.3)'
    },
    line_height_loose: {
      css_var: '--line-height-loose',
      default: 1.75,
      type: :decimal,
      label: 'Loose Line Height',
      description: 'Loose line height for readability (1.7-2.0)'
    },

    # ===== Layout & Spacing =====
    layout_width: {
      css_var: '--container-max',
      default: 'standard',
      type: :enum,
      values: ['narrow', 'standard', 'wide', 'full'],
      transform: ->(v) {
        {
          'narrow' => '900px',
          'standard' => '1200px',
          'wide' => '1400px',
          'full' => '100%'
        }[v]
      },
      label: 'Layout Width',
      description: 'Maximum container width'
    },
    spacing_unit: {
      css_var: '--spacing-unit',
      default: 1.0,
      type: :decimal,
      suffix: 'rem',
      label: 'Spacing Unit',
      description: 'Base spacing scale (0.5-2.0 rem)'
    },
    spacing_section: {
      css_var: '--spacing-section',
      default: 4.0,
      type: :decimal,
      suffix: 'rem',
      label: 'Section Spacing',
      description: 'Spacing between major sections (2-8 rem)'
    },

    # ===== Effects =====
    radius_sm: {
      css_var: '--radius-sm',
      default: '4px',
      type: :string,
      label: 'Small Radius',
      description: 'Border radius for small elements (2-4px)'
    },
    radius_default: {
      css_var: '--radius-default',
      default: '8px',
      type: :string,
      label: 'Default Radius',
      description: 'Default border radius (6-12px)'
    },
    radius_lg: {
      css_var: '--radius-lg',
      default: '16px',
      type: :string,
      label: 'Large Radius',
      description: 'Border radius for large elements (12-24px)'
    },
    border_width: {
      css_var: '--border-width',
      default: '1px',
      type: :string,
      label: 'Border Width',
      description: 'Default border width (1-2px)'
    },
    shadow_sm: {
      css_var: '--shadow-sm',
      default: '0 1px 2px 0 rgb(0 0 0 / 0.05)',
      type: :text,
      label: 'Small Shadow',
      description: 'Subtle shadow for slight elevation'
    },
    shadow_default: {
      css_var: '--shadow-default',
      default: '0 1px 3px 0 rgb(0 0 0 / 0.1)',
      type: :text,
      label: 'Default Shadow',
      description: 'Default shadow for cards and panels'
    },
    shadow_lg: {
      css_var: '--shadow-lg',
      default: '0 10px 15px -3px rgb(0 0 0 / 0.1)',
      type: :text,
      label: 'Large Shadow',
      description: 'Prominent shadow for modals and overlays'
    }
  }.freeze

  # Group fields for admin UI organization
  GROUPS = {
    brand: {
      label: 'Brand Colors',
      icon: 'palette',
      fields: [:primary_color, :primary_hover_color, :secondary_color, :secondary_hover_color]
    },
    neutrals: {
      label: 'Neutrals',
      icon: 'adjust',
      fields: [:background_color, :surface_color, :surface_hover_color]
    },
    text: {
      label: 'Text',
      icon: 'text',
      fields: [:text_color, :text_muted_color, :text_subtle_color, :heading_color]
    },
    interactive: {
      label: 'Interactive',
      icon: 'link',
      fields: [:link_color, :link_hover_color, :link_visited_color]
    },
    states: {
      label: 'UI States',
      icon: 'alert-circle',
      fields: [:border_color, :border_strong_color, :focus_color, :success_color, :warning_color, :error_color, :info_color]
    },
    typography: {
      label: 'Typography',
      icon: 'type',
      fields: [:font_heading, :font_body, :font_mono, :font_size_base, :line_height_base, :line_height_tight, :line_height_loose]
    },
    layout: {
      label: 'Layout',
      icon: 'layout',
      fields: [:layout_width, :spacing_unit, :spacing_section]
    },
    effects: {
      label: 'Effects',
      icon: 'box',
      fields: [:radius_sm, :radius_default, :radius_lg, :border_width, :shadow_sm, :shadow_default, :shadow_lg]
    }
  }.freeze

  # Helper: Get all field names
  def self.field_names
    FIELDS.keys
  end

  # Helper: Get fields by type
  def self.fields_by_type(type)
    FIELDS.select { |_, config| config[:type] == type }.keys
  end

  # Helper: Get default value for a field
  def self.default_for(field)
    FIELDS[field][:default]
  end

  # Helper: Get CSS variable name for a field
  def self.css_var_for(field)
    FIELDS[field][:css_var]
  end

  # Helper: Format value for CSS output
  def self.format_value(field, value)
    config = FIELDS[field]
    return value if value.nil?

    # Apply transform if defined
    value = config[:transform].call(value) if config[:transform]

    # Add suffix if defined
    value = "#{value}#{config[:suffix]}" if config[:suffix] && !value.to_s.include?(config[:suffix])

    value
  end
end
