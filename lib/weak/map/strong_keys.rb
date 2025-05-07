# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require "set"

require "weak/map/abstract_strong_keys"
require "weak/undefined"

##
module Weak
  class Map
    # This {Weak::Map} strategy targets JRuby >= 9.4.6.0 and TruffleRuby >= 22.
    # Older versions require additional indirections implemented in
    # {StrongSecondaryKeys}:
    #
    # - https://github.com/jruby/jruby/issues/7862
    # - https://github.com/oracle/truffleruby/issues/2267
    #
    # The `ObjectSpace::WeakMap` on JRuby and TruffleRuby has strong keys and
    # weak values. Thus, only the value object in an `ObjectSpace::WeakMap` can
    # be garbage collected to remove the entry while the key defines a strong
    # object reference which prevents the key object from being garbage
    # collected.
    #
    # As a workaround, we use the element's object_id as a key. Being an
    # `Integer`, the object_id is generally is not garbage collected anyway but
    # allows to uniquely identity the object.
    #
    # As we need to store both a key and value object for each key-value pair in
    # our `Weak::Map`, we use two separate `ObjectSpace::WeakMap` objects for
    # storing those. This allows keys and values to be independently garbage
    # collected. When accessing a logical key in the {Weak::Map}, we need to
    # manually check if we have a valid entry for both the stored key and the
    # associated value.
    #
    # The `ObjectSpace::WeakMap` does not allow to explicitly delete entries. We
    # emulate this by setting the garbage-collectible value of a deleted entry
    # to a simple new object. This value will be garbage collected on the next
    # GC run which will then remove the entry. When accessing elements, we
    # delete and filter out these recently deleted entries.
    module StrongKeys
      include AbstractStrongKeys

      # Checks if this strategy is usable for the current Ruby version.
      #
      # @return [Bool] truethy for Ruby, TruffleRuby and modern JRuby, falsey
      #   otherwise
      def self.usable?
        case RUBY_ENGINE
        when "ruby", "truffleruby"
          true
        when "jruby"
          Gem::Version.new(RUBY_ENGINE_VERSION) >= Gem::Version.new("9.4.6.0")
        end
      end

      # @!macro weak_map_accessor_read
      def [](key)
        _get(key.__id__) { _default(key) }
      end

      # @!macro weak_map_accessor_write
      def []=(key, value)
        id = key.__id__

        @keys[id] = key.nil? ? NIL : key
        @values[id] = value.nil? ? NIL : value
        value
      end

      # @!macro weak_map_method_clear
      def clear
        @keys = ObjectSpace::WeakMap.new
        @values = ObjectSpace::WeakMap.new
        self
      end

      # @!macro weak_map_method_delete
      def delete(key)
        _delete(key.__id__) { yield(key) if block_given? }
      end

      # @!macro weak_map_method_each_key
      def each_key
        return enum_for(__method__) { size } unless block_given?

        @keys.values.each do |raw_key|
          next if DeletedEntry === raw_key

          key = value!(raw_key)
          id = key.__id__
          if missing?(@values[id])
            @keys[id] = DeletedEntry.new
          else
            yield key
          end
        end

        self
      end

      # @!macro weak_map_method_each_pair
      def each_pair
        return enum_for(__method__) { size } unless block_given?

        @keys.values.each do |raw_key|
          next if DeletedEntry === raw_key

          key = value!(raw_key)
          id = key.__id__

          raw_value = @values[id]
          if missing?(raw_value)
            @keys[id] = DeletedEntry.new
          else
            yield [key, value!(raw_value)]
          end
        end

        self
      end

      # @!macro weak_map_method_each_value
      def each_value
        return enum_for(__method__) { size } unless block_given?

        @keys.values.each do |raw_key|
          next if DeletedEntry === raw_key

          key = value!(raw_key)
          id = key.__id__

          raw_value = @values[id]
          if missing?(raw_value)
            @keys[id] = DeletedEntry.new
          else
            yield value!(raw_value)
          end
        end

        self
      end

      # @!macro weak_map_method_fetch
      def fetch(key, default = UNDEFINED, &block)
        _get(key.__id__) { _fetch_default(key, default, &block) }
      end

      # @!macro weak_map_method_include_question
      def include?(key)
        _get(key.__id__) { return false }
        true
      end

      # @!macro weak_map_method_prune
      def prune
        value_keys = ::Set.new(@values.keys)

        @keys.keys.each do |id|
          next if value_keys.delete?(id)
          @keys[id] = DeletedEntry.new
        end

        value_keys.each do |id|
          @values[id] = DeletedEntry.new
        end

        self
      end

      private

      def auto_prune
        s1 = @keys.size
        s2 = @values.size
        s1, s2 = s2, s1 if s1 < s2

        cutoff = [2000, (s1 * 0.2).ceil].max
        prune unless s1 - s2 > cutoff
      end
    end
  end
end
