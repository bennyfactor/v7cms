# frozen_string_literal: true

module V7CMS
  class FormRenderer
    def self.render(form)
      new(form).render
    end

    def initialize(form)
      @form = form
      @fields = form.form_fields.to_a
    end

    def render
      lines = []
      lines << %(<form action="/forms/#{@form.slug}/submit" method="POST" data-form-slug="#{@form.slug}"#{recaptcha_attr}>)
      lines << '  <div class="form-fields space-y-6">'
      @fields.each { |field| lines << render_field(field) }
      lines << '  </div>'
      lines << '  <div class="form-actions mt-6">'
      lines << %(    <button type="submit" class="bg-blue-600 text-white px-6 py-2 rounded-lg hover:bg-blue-700 transition">#{escape(@form.submit_button_text)}</button>)
      lines << '  </div>'
      lines << '  <div class="form-message hidden mt-4"></div>'
      lines << '</form>'
      lines.join("\n")
    end

    private

    def recaptcha_attr
      @form.require_recaptcha ? ' data-recaptcha="true"' : ''
    end

    def render_field(field)
      return render_hidden(field) if field.field_type == 'hidden'

      lines = []
      lines << '    <div class="form-field">'
      lines << render_label(field) if field.label.present?
      lines << render_input(field)
      lines << %(      <small class="text-gray-500 text-sm">#{escape(field.help_text)}</small>) if field.help_text.present?
      lines << '    </div>'
      lines.join("\n")
    end

    def render_label(field)
      required_mark = field.required? ? ' <span class="text-red-500">*</span>' : ''
      %(      <label for="field_#{field.name}" class="block text-sm font-medium text-gray-700 mb-1">#{escape(field.label)}#{required_mark}</label>)
    end

    def render_input(field)
      case field.field_type
      when 'textarea' then render_textarea(field)
      when 'select' then render_select(field)
      when 'radio' then render_radio(field)
      when 'checkbox' then render_checkbox(field)
      else render_standard_input(field)
      end
    end

    def render_standard_input(field)
      attrs = common_attrs(field)
      rules = field.parsed_validation_rules
      attrs << %( min="#{rules['min']}") if rules['min']
      attrs << %( max="#{rules['max']}") if rules['max']
      attrs << %( minlength="#{rules['min_length']}") if rules['min_length']
      attrs << %( maxlength="#{rules['max_length']}") if rules['max_length']
      attrs << %( pattern="#{escape(rules['pattern'])}") if rules['pattern']
      %(      <input type="#{field.field_type}"#{attrs} class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-blue-500">)
    end

    def render_textarea(field)
      attrs = common_attrs(field)
      rules = field.parsed_validation_rules
      attrs << %( minlength="#{rules['min_length']}") if rules['min_length']
      attrs << %( maxlength="#{rules['max_length']}") if rules['max_length']
      %(      <textarea#{attrs} rows="4" class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-blue-500"></textarea>)
    end

    def render_select(field)
      lines = []
      attrs = common_attrs(field)
      lines << %(      <select#{attrs} class="w-full border border-gray-300 rounded-lg px-3 py-2 focus:ring-2 focus:ring-blue-500 focus:border-blue-500">)
      lines << '        <option value="">Select...</option>'
      field.parsed_options.each do |opt|
        lines << %(        <option value="#{escape(opt['value'])}">#{escape(opt['label'])}</option>)
      end
      lines << '      </select>'
      lines.join("\n")
    end

    def render_radio(field)
      lines = []
      lines << '      <fieldset class="space-y-2">'
      field.parsed_options.each_with_index do |opt, i|
        id = "field_#{field.name}_#{i}"
        req = field.required? ? ' required' : ''
        lines << '        <div class="flex items-center">'
        lines << %(          <input type="radio" id="#{id}" name="#{field.name}" value="#{escape(opt['value'])}"#{req} class="mr-2">)
        lines << %(          <label for="#{id}">#{escape(opt['label'])}</label>)
        lines << '        </div>'
      end
      lines << '      </fieldset>'
      lines.join("\n")
    end

    def render_checkbox(field)
      req = field.required? ? ' required' : ''
      lines = []
      lines << '      <div class="flex items-center">'
      lines << %(        <input type="checkbox" id="field_#{field.name}" name="#{field.name}" value="true"#{req} class="mr-2">)
      lines << %(        <label for="field_#{field.name}">#{escape(field.label)}</label>)
      lines << '      </div>'
      lines.join("\n")
    end

    def render_hidden(field)
      value = field.parsed_validation_rules['value'] || ''
      %(    <input type="hidden" name="#{field.name}" value="#{escape(value)}">)
    end

    def common_attrs(field)
      attrs = %( id="field_#{field.name}" name="#{field.name}")
      attrs << %( placeholder="#{escape(field.placeholder)}") if field.placeholder.present?
      attrs << ' required' if field.required?
      attrs
    end

    def escape(text)
      return '' if text.nil?

      text.to_s.gsub('&', '&amp;').gsub('"', '&quot;').gsub('<', '&lt;').gsub('>', '&gt;')
    end
  end
end
