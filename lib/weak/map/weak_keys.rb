# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require "weak/map/deletable"

##
module Weak
  class Map
    # This {Weak::Map} strategy targets Ruby < 3.3.0.
    #
    # Its `ObjectSpace::WeakMap` uses weak keys and weak values so that either
    # the key or the value can be independently garbage collected. If either of
    # them vanishes, the entry is removed.
    #
    # The `ObjectSpace::WeakMap` does not allow to explicitly delete entries.
    # We emulate this by setting the garbage-collectible value of a deleted
    # entry to a simple new object. This value will be garbage collected on the
    # next GC run which will then remove the entry. When accessing elements, we
    # delete and filter out these recently deleted entries.
    module WeakKeys
      include Deletable

      # Checks if this strategy is usable for the current Ruby version.
      #
      # @return [Bool] truethy for Ruby (aka. MRI, aka. YARV), falsey otherwise
      def self.usable?
        RUBY_ENGINE == "ruby"
      end

      # @!macro weak_map_accessor_read
      def [](key)
        raw_value = @map[key]
        missing?(raw_value) ? _default(key) : value!(raw_value)
      end

      # @!macro weak_map_accessor_write
      def []=(key, value)
        @map[key] = value.nil? ? NIL : value
        value
      end

      # @!macro weak_map_method_clear
      def clear
        @map = ObjectSpace::WeakMap.new
        self
      end

      # @!macro weak_map_method_delete
      def delete(key)
        raw_value = @map[key]
        if have?(raw_value)
          @map[key] = DeletedEntry.new
          value!(raw_value)
        elsif block_given?
          yield(key)
        end
      end

      # @!macro weak_map_method_each_key
      def each_key
        return enum_for(__method__) { size } unless block_given?

        @map.keys.each do |key|
          yield key unless missing?(@map[key])
        end
        self
      end

      # @!macro weak_map_method_each_pair
      def each_pair
        return enum_for(__method__) { size } unless block_given?

        @map.keys.each do |key|
          raw_value = @map[key]
          yield [key, value!(raw_value)] unless missing?(raw_value)
        end
        self
      end

      # @!macro weak_map_method_each_value
      def each_value
        return enum_for(__method__) { size } unless block_given?

        @map.values.each do |raw_value|
          yield value!(raw_value) unless missing?(raw_value)
        end
        self
      end

      # @!macro weak_map_method_fetch
      def fetch(key, default = UNDEFINED, &block)
        raw_value = @map[key]
        if have?(raw_value)
          value!(raw_value)
        else
          _fetch_default(key, default, &block)
        end
      end

      # @!macro weak_map_method_include_question
      def include?(key)
        have?(@map[key])
      end

      # @!macro weak_map_method_keys
      def keys
        @map.keys.delete_if { |key| missing?(@map[key]) }
      end

      # @!macro weak_map_method_prune
      def prune
        self
      end

      # @!macro weak_map_method_size
      def size
        each_key.count
      end

      # @!macro weak_map_method_values
      def values
        values = []
        @map.values.each do |raw_value|
          values << value!(raw_value) unless missing?(raw_value)
        end
        values
      end
    end
  end
end
