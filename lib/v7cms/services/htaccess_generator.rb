# frozen_string_literal: true

module V7CMS
  class HtaccessGenerator
    # Template is in the gem's templates directory
    TEMPLATE_PATH = File.expand_path('../templates/.htaccess.template', __dir__).freeze
    PLACEHOLDER = '{{REDIRECTS}}'.freeze

    def self.generate
      new.generate
    end

    # Output path is in the user's project root
    def output_path
      File.join(V7CMS.project_root, '.htaccess')
    end

    def generate
      template = File.read(TEMPLATE_PATH)
      redirects_block = build_redirects_block
      output = template.gsub(PLACEHOLDER, redirects_block)
      File.write(output_path, output)
      Logger.new(STDOUT).info("HtaccessGenerator: .htaccess regenerated with #{V7CMS::Redirect.count} redirects")
      true
    rescue StandardError => e
      Logger.new(STDOUT).error("HtaccessGenerator failed: #{e.message}")
      false
    end

    private

    def build_redirects_block
      redirects = V7CMS::Redirect.order(:short_path)
      return "# No custom redirects configured" if redirects.empty?

      redirects.map do |r|
        "RewriteRule ^#{escape_path(r.short_path)}$ #{r.target_path} [R=301,L]"
      end.join("\n")
    end

    def escape_path(path)
      path.sub(/^\//, '').gsub(/[.?*+^$\[\](){}|\\]/, '\\\\\&')
    end
  end
end
