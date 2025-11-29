class HtaccessGenerator
  TEMPLATE_PATH = File.expand_path('../../.htaccess.template', __dir__).freeze
  OUTPUT_PATH = File.expand_path('../../.htaccess', __dir__).freeze
  PLACEHOLDER = '{{REDIRECTS}}'.freeze

  def self.generate
    new.generate
  end

  def generate
    template = File.read(TEMPLATE_PATH)
    redirects_block = build_redirects_block
    output = template.gsub(PLACEHOLDER, redirects_block)
    File.write(OUTPUT_PATH, output)
    Logger.new(STDOUT).info("HtaccessGenerator: .htaccess regenerated with #{Redirect.count} redirects")
    true
  rescue StandardError => e
    Logger.new(STDOUT).error("HtaccessGenerator failed: #{e.message}")
    false
  end

  private

  def build_redirects_block
    redirects = Redirect.order(:short_path)
    return "# No custom redirects configured" if redirects.empty?

    redirects.map do |r|
      "RewriteRule ^#{escape_path(r.short_path)}$ #{r.target_path} [R=301,L]"
    end.join("\n")
  end

  def escape_path(path)
    path.sub(/^\//, '').gsub(/[.?*+^$\[\](){}|\\]/, '\\\\\&')
  end
end
