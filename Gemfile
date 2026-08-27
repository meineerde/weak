# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

source "https://rubygems.org"
gemspec name: "weak", require: false

ruby34 = Gem::Requirement.new(">= 3.4.0") === Gem.ruby_version

gem "rake", "~> 13.0"

group :development do
  gem "irb" if ruby34
end

group :doc do
  gem "yard", require: false
  gem "rdoc", require: false if ruby34
end

group :test do
  gem "rspec", "~> 3.0", require: false

  gem "standard", "~> 1.45", require: false
  # rubocop-rspec pinned until standardrb compatibility is restored
  # https://github.com/standardrb/standard/issues/701
  gem "rubocop-rspec", "~> 3.4.0 ", require: false

  gem "simplecov", require: false
  gem "coveralls_reborn", require: false

  # Pin jar-dependencies gem (which is a deep transitive dependency of irb via
  # the coveralls_reborn gem) to the specific version shipped with older JRuby
  # versions.
  # https://github.com/jruby/jruby/issues/7262
  if RUBY_ENGINE == "jruby" && Gem::Requirement.new("< 9.4.10.0") === Gem::Version.new(RUBY_ENGINE_VERSION)
    gem "jar-dependencies", "0.4.1"
  end

  # Restrict json gem on Truffleruby 22 as newer versions do not compile there
  if RUBY_ENGINE == "truffleruby" && RUBY_ENGINE_VERSION.to_i < 23
    gem "json", "~> 2.5.1"
  end
end
