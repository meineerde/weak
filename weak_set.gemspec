# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require_relative "lib/weak_set/version"

Gem::Specification.new do |spec|
  spec.name = "weak_set"
  spec.version = WeakSet::VERSION
  spec.authors = ["Holger Just"]
  spec.summary = <<~TXT
    A collection of unordered values without strong object references.
  TXT
  spec.description = <<~TXT
    WeakSet behaves similar to the Set class of the Ruby standard library.
    But all values only have a weak references from the set which does not
    prevent the referenced value from being garbage collected unless someone
    still has a separate reference to it.
  TXT

  spec.files = %w[
    lib/**/*.rb
    CHANGELOG.md
    CODE_OF_CONDUCT.md
    LICENSE.txt
    README.md
  ].flat_map { |glob| Dir.glob(glob, base: __dir__) }
  spec.require_paths = ["lib"]

  spec.homepage = "https://github.com/meineerde/weak_set"
  spec.license = "MIT"

  spec.metadata = {
    "rubygems_mfa_required" => "true",

    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/meineerde/weak_set",
    "changelog_uri" => "https://github.com/meineerde/weak_set/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://www.rubydoc.info/gems/weak_set/#{spec.version}"
  }

  spec.required_ruby_version = ">= 3.0.0"
end
