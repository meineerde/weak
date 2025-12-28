# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

##
module Weak
  # Version information about {Weak}. We follow semantic versioning.
  module Version
    # MAJOR version. It is incremented after incompatible API changes
    MAJOR = 0
    # MINOR version. It is incremented after adding functionality in a
    # backwards-compatible manner
    MINOR = 2
    # PATCH version. It is incremented when making backwards-compatible
    # bug-fixes.
    PATCH = 1
    # PRERELEASE suffix. Set to a alphanumeric string on any pre-release
    # versions like beta or RC releases; `nil` on regular releases
    PRERELEASE = nil

    # The {Weak} version as a `Gem::Version` string. We follow semantic
    # versioning.
    # @see https://semver.org/
    STRING = [MAJOR, MINOR, PATCH, PRERELEASE].compact.join(".").freeze

    # @return [Gem::Version] the {Weak} version as a `Gem::Version` object
    def self.gem_version
      Gem::Version.new STRING
    end

    # @return [String] the Weak version as a `Gem::Version` string
    def self.to_s
      STRING
    end
  end

  # (see Version::STRING)
  VERSION = Weak::Version::STRING
end
