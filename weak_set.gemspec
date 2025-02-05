# frozen_string_literal: true

require_relative "lib/weak_set/version"

Gem::Specification.new do |spec|
  spec.name = "weak_set"
  spec.version = WeakSet::VERSION
  spec.authors = ["Holger Just"]

  spec.summary = <<~TXT
    A collection of unordered values without strong object references.
  TXT
  spec.homepage = "https://github.com/meineerde/weak_set"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/meineerde/weak_set"
  spec.metadata["changelog_uri"] =
    "https://github.com/meineerde/weak_set/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github Gemfile])
    end
  end

  spec.require_paths = ["lib"]
end
