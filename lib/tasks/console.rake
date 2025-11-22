  desc "Open an IRB session with the app loaded"
  task :console do
    require_relative '../../app/cms'
    require 'irb'
    ARGV.clear
    IRB.start
  end
