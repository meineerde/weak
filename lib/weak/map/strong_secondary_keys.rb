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
    # This {Weak::Map} strategy targets JRuby < 9.4.6.0.
    #
    # These JRuby versions have a similar `ObjectSpace::WeakMap` as newer
    # JRubies with strong keys and weak values. Thus, only the value object can
    # be garbage collected to remove the entry while the key defines a strong
    # object reference which prevents the key object from being garbage
    # collected.
    #
    # As we need to store both a key and value object for each key-value pair in
    # our `Weak::Map`, we use two separate `ObjectSpace::WeakMap` objects for
    # storing those. This allows keys and values to be independently garbage
    # collected. When accessing a logical key in the {Weak::Map}, we need to
    # manually check if we have a valid entry for both the stored key and the
    # associated value.
    #
    # Additionally, `Integer` values (including object_ids) can have multiple
    # different object representations in JRuby, making them not strictly equal.
    # Thus, we can not use the object_id as a key in an `ObjectSpace::WeakMap`
    # as we do in {Weak::Map::StrongKeys} for newer JRuby versions.
    #
    # As a workaround we use a more indirect implementation with a secondary
    # lookup table for the `ObjectSpace::WeakMap` keys which is inspired by
    # [Google::Protobuf::Internal::LegacyObjectCache](https://github.com/protocolbuffers/protobuf/blob/afe2de261861717026c3b57ec83678590d5de838/ruby/lib/google/protobuf/internal/object_cache.rb#L42-L96)
    #
    # This secondary key map is a regular Hash which stores a mapping from the
    # key's object_id to a separate Object which in turn is used as a key
    # in the `ObjectSpace::WeakMap` for the stored keys and values.
    #
    # Being a regular Hash, the keys and values of the secondary key map are not
    # automatically garbage collected as elements in the `ObjectSpace::WeakMap`
    # are removed. However, its entries are rather cheap with Integer keys and
    # "empty" objects as values.
    #
    # As this strategy is the most conservative with the fewest requirements to
    # the `ObjectSpace::WeakMap`, we use it as a default or fallback if there is
    # no better strategy.
    module StrongSecondaryKeys
      include AbstractStrongKeys

      # Checks if this strategy is usable for the current Ruby version.
      #
      # @return [Bool] always `true` to indicate that this stragegy should be
      #   usable with any Ruby implementation which provides an
      #   `ObjectSpace::WeakMap`.
      def self.usable?
        true
      end

      # @!macro weak_map_accessor_read
      def [](key)
        id = @key_map[key.__id__]
        unless id
          auto_prune
          return _default(key)
        end

        _get(id) { _default(key) }
      end

      # @!macro weak_map_accessor_write
      def []=(key, value)
        id = @key_map[key.__id__] ||= Object.new.freeze

        @keys[id] = key.nil? ? NIL : key
        @values[id] = value.nil? ? NIL : value
        value
      end

      # @!macro weak_map_method_clear
      def clear
        @keys = ObjectSpace::WeakMap.new
        @values = ObjectSpace::WeakMap.new
        @key_map = {}
        self
      end

      # @!macro weak_map_method_delete
      def delete(key)
        id = @key_map[key.__id__]
        return block_given? ? yield(key) : nil unless id

        _delete(id) { yield(key) if block_given? }
      end

      # @!macro weak_map_method_each_key
      def each_key
        return enum_for(__method__) { size } unless block_given?

        @keys.values.each do |raw_key|
          next if DeletedEntry === raw_key

          key = value!(raw_key)
          next unless (id = @key_map[key.__id__])
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
          next unless (id = @key_map[key.__id__])

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
          next unless (id = @key_map[key.__id__])

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
        id = @key_map[key.__id__]
        unless id
          auto_prune
          return _fetch_default(key, default, &block)
        end

        _get(id) { _fetch_default(key, default, &block) }
      end

      # @!macro weak_map_method_include_question
      def include?(key)
        id = @key_map[key.__id__]
        unless id
          auto_prune
          return false
        end

        _get(id) { return false }
        true
      end

      # @!macro weak_map_method_prune
      def prune
        orphaned_value_keys = ::Set.new(@values.keys)
        remaining_keys = ::Set.new

        @keys.keys.each do |id|
          if orphaned_value_keys.delete?(id)
            # Here, we have found a valid value belonging to the key. As both
            # key and value are valid, we keep the @key_map entry.
            remaining_keys << id
          else
            # Here, the value was missing (i.e. garbage collected). We mark the
            # still present key as deleted
            @keys[id] = DeletedEntry.new
          end
        end

        # Mark all (remaining) values as deleted for which we have not found a
        # matching key above
        orphaned_value_keys.each do |id|
          @values[id] = DeletedEntry.new
        end

        # Finally, remove all @key_map entries for which we have not seen a
        # valid key and value above
        @key_map.keep_if { |_, id| remaining_keys.include?(id) }

        self
      end

      private

      # prune unneeded entries from the `@key_map` Hash as well as
      # garbage-collected entries from `@keys` and `@values` if we could remove
      # at least 2000 entries or 20% of the table size (whichever is greater).
      # Since the cost of the GC pass is O(N), we want to make sure that we
      # condition this on overall table size, to avoid O(N^2) CPU costs.
      def auto_prune
        key_map_size = @key_map.size
        cutoff = [2000, (key_map_size * 0.2).ceil].max
        key_value_size = [@keys.size, @values.size].max

        prune if key_map_size - key_value_size > cutoff
      end
    end
  end
end
