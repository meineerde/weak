# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require_relative "lib/weak/version"

Gem::Specification.new do |spec|
  spec.name = "weak"
  spec.version = Weak::VERSION
  spec.authors = ["Holger Just"]
  spec.summary = <<~TXT
    Tools to use handle collections of weak-referenced values in Ruby
  TXT
  spec.description = <<~TXT
    The Weak library provides a Weak::Set class to store an unordered list of
    objects. The collection classes only hold weak references to all elements
    so they can be garbage-collected when there are no more references left.
  TXT

  spec.files = %w[
    lib/**/*.rb
    CHANGELOG.md
    CODE_OF_CONDUCT.md
    LICENSE.txt
    README.md
  ].flat_map { |glob| Dir.glob(glob, base: __dir__) }
  spec.require_paths = ["lib"]

  spec.homepage = "https://github.com/meineerde/weak"
  spec.license = "MIT"

  spec.metadata = {
    "rubygems_mfa_required" => "true",

    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/meineerde/weak",
    "changelog_uri" => "https://github.com/meineerde/weak/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://www.rubydoc.info/gems/weak/#{spec.version}"
  }

  spec.required_ruby_version = ">= 3.0.0"
end
