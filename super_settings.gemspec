Gem::Specification.new do |spec|
  spec.name = "super_settings"
  spec.version = File.read(File.expand_path("../VERSION", __FILE__)).strip
  spec.authors = ["Brian Durand"]
  spec.email = ["bbdurand@gmail.com"]

  spec.summary = "SuperSettings provides a scalable framework for managing dynamic runtime application settings with in-memory caching, strong typing, a built-in web UI, and support for multiple storage backends."

  spec.homepage = "https://github.com/bdurand/super_settings"
  spec.license = "MIT"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/main/CHANGELOG.md"
  }

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  ignore_files = %w[
    .
    Appraisals
    Gemfile
    Gemfile.lock
    Rakefile
    docker-compose.yml
    config.ru
    assets/
    bin/
    gemfiles/
    spec/
  ]
  spec.files = Dir.chdir(File.expand_path("..", __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| ignore_files.any? { |path| f.start_with?(path) } }
  end

  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler"

  spec.required_ruby_version = ">= 2.6"
end
