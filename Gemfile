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
end
