begin
  require "bundler/setup"
rescue LoadError
  puts "You must `gem install bundler` and `bundle install` to run rake tasks"
end

require "yard"

YARD::Rake::YardocTask.new(:yard)

if defined?(Rails)
  APP_RAKEFILE = File.expand_path("spec/dummy/Rakefile", __dir__)
  load "rails/tasks/engine.rake"

  load "rails/tasks/statistics.rake"
end

require "bundler/gem_tasks"

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task default: :spec

desc "run the specs using appraisal"
task :appraisals do
  exec "bundle exec appraisal rake spec"
end

namespace :appraisals do
  desc "install all the appraisal gemspecs"
  task :install do
    exec "bundle exec appraisal install"
  end
end

require "standard/rake"
