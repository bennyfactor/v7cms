namespace :htaccess do
  desc "Generate .htaccess from template and redirects"
  task generate: :environment do
    puts "Generating .htaccess..."
    if HtaccessGenerator.generate
      puts "  ✓ .htaccess generated successfully (#{Redirect.count} redirects)"
    else
      puts "  ✗ Failed to generate .htaccess"
      exit 1
    end
  end
end
