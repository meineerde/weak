# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require "weak/undefined"

##
module Weak
  class Map
    # This {Weak::Map} strategy targets Ruby >= 3.3.0.
    # Older Ruby versions require additional indirections implemented in
    # {Weak::Map::WeakKeys}:
    #
    # - https://bugs.ruby-lang.org/issues/19561
    #
    # Ruby's `ObjectSpace::WeakMap` uses weak keys and weak values so that
    # either the key or the value can be independently garbage collected. If
    # either of them vanishes, the entry is removed.
    #
    # The `ObjectSpace::WeakMap` also allows to delete entries. This allows us
    # to directly use the `ObjectSpace::WeakMap` as a storage the same way a
    # `Set` uses a `Hash` object object as storage.
    module WeakKeysWithDelete
      # Checks if this strategy is usable for the current Ruby version.
      #
      # @return [Bool] truethy for Ruby (aka. MRI, aka. YARV) >= 3.3.0,
      #   falsey otherwise
      def self.usable?
        RUBY_ENGINE == "ruby" &&
          ObjectSpace::WeakMap.instance_methods.include?(:delete)
      end

      # @!macro weak_map_accessor_read
      def [](key)
        value = @map[key]
        value = _default(key) if value.nil? && !@map.key?(key)
        value
      end

      # @!macro weak_map_accessor_write
      def []=(key, value)
        @map[key] = value
        value
      end

      # @!macro weak_map_method_clear
      def clear
        @map = ObjectSpace::WeakMap.new
        self
      end

      # @!macro weak_map_method_delete
      def delete(key, &block)
        @map.delete(key, &block)
      end

      # @!macro weak_map_method_each_key
      def each_key
        return enum_for(__method__) { size } unless block_given?

        @map.keys.each do |key|
          yield(key)
        end

        self
      end

      # @!macro weak_map_method_each_pair
      def each_pair(&block)
        return enum_for(__method__) { size } unless block_given?

        array = []
        @map.each do |key, value|
          array << key << value
        end
        array.each_slice(2, &block)

        self
      end

      # @!macro weak_map_method_each_value
      def each_value
        return enum_for(__method__) { size } unless block_given?

        @map.values.each do |value|
          yield(value)
        end

        self
      end

      # @!macro weak_map_method_fetch
      def fetch(key, default = UNDEFINED, &block)
        value = @map[key]
        value = _fetch_default(key, default, &block) if value.nil? && !@map.key?(key)
        value
      end

      # @!macro weak_map_method_include_question
      def include?(key)
        @map.key?(key)
      end

      # @!macro weak_map_method_keys
      def keys
        @map.keys
      end

      # @!macro weak_map_method_prune
      def prune
        self
      end

      # @!macro weak_map_method_size
      def size
        @map.size
      end

      # @!macro weak_map_method_values
      def values
        @map.values
      end
    end
  end
end
