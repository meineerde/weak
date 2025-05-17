# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require "spec_helper"
require "weak/version"

RSpec.describe "Weak::Version" do
  it "defines a major version" do
    expect(Weak::Version::MAJOR).to be_a(Integer).and be >= 0
  end

  it "defines a minor version" do
    expect(Weak::Version::MINOR).to be_a(Integer).and be >= 0
  end

  it "defines a patch version" do
    expect(Weak::Version::PATCH).to be_a(Integer).and be >= 0
  end

  it "may define a valid prerelease version" do
    expect(Weak::Version::PRERELEASE)
      .to be_nil
      .or be_a(String).and be_frozen.and match(/\A[a-z0-9_-]+\z/)
  end

  it "has a version number" do
    expect(Weak::Version::STRING)
      .to be_a(String)
      .and be_frozen
      .and match %r{\A\d+(?:\.\d+)+(?:\.[a-z][a-z0-9_]+)?\z}i
  end

  describe ".to_s" do
    it "equals Weak::Version::STRING" do
      expect(Weak::Version.to_s).to equal Weak::Version::STRING
    end
  end

  describe ".gem_version" do
    it "is a Gem::Version" do
      expect(Weak::Version.gem_version).to be_a Gem::Version
    end

    it "matches Weak::Version::STRING" do
      expect(Weak::Version.gem_version.to_s).to eq Weak::Version::STRING
    end
  end

  it "exposes the version as Weak::VERSION" do
    expect(Weak::VERSION).to equal Weak::Version::STRING
  end
end
