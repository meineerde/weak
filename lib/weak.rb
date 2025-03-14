# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require "singleton"

require_relative "weak/version"
require_relative "weak/map"
require_relative "weak/set"

# Weak is a Ruby library which implements collections of unordered values
# without strong object references.
#
# We provide multiple classes which behave similar to their standard-library
# counterparts. However, all elements are only weakly referenced. That way, all
# elements can be garbage collected and silently removed from the collection
# unless they are still referenced from some other live object.
module Weak
  # A class for the {UNDEFINED} object. Being a singleton, there will only be
  # exactly one object of this class: the {UNDEFINED} object.
  #
  # @private
  class UndefinedClass
    include Singleton

    def initialize
      freeze
    end

    # @return [String] the string `"UNDEFINED"`
    def to_s
      "UNDEFINED"
    end
    alias_method :inspect, :to_s
  end

  # The {UNDEFINED} object can be used as the default value for method arguments
  # to distinguish it from `nil`.
  #
  # @see https://holgerjust.de/2016/detecting-default-arguments-in-ruby/#special-default-value
  UNDEFINED = UndefinedClass.instance
end
