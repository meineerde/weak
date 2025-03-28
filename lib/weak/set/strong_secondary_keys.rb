# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

##
module Weak
  class Set
    # This {Weak::Set} strategy targets JRuby < 9.4.6.0.
    #
    # These JRuby versions have a similar `ObjectSpace::WeakMap` as newer
    # JRubies with strong keys and weak values. Thus, only the value object can
    # be garbage collected to remove the entry while the key defines a strong
    # object reference which prevents the key object from being garbage
    # collected.
    #
    # Additionally, `Integer` values (including object_ids) can have multiple
    # different object representations in JRuby, making them not strictly equal.
    # Thus, we can not use the object_id as a key in an `ObjectSpace::WeakMap`
    # as we do in {Weak::Set::StrongKeys} for newer JRuby versions.
    #
    # As a workaround we use a more indirect implementation with a secondary
    # lookup table for the keys which is inspired by
    # [Google::Protobuf::Internal::LegacyObjectCache](https://github.com/protocolbuffers/protobuf/blob/afe2de261861717026c3b57ec83678590d5de838/ruby/lib/google/protobuf/internal/object_cache.rb#L42-L96)
    #
    # This secondary key map is a regular Hash which stores a mapping from an
    # element's object_id to a separate Object which in turn is used as the key
    # in the `ObjectSpace::WeakMap`.
    #
    # Being a regular Hash, the keys and values of the secondary key map are not
    # automatically garbage collected as elements in the `ObjectSpace::WeakMap`
    # are removed. However, its entries are rather cheap with Integer keys and
    # "empty" objects as values. We perform manual garbage collection of this
    # secondary key map during {StrongSecondaryKeys#include?} if required.
    #
    # As this strategy is the most conservative with the fewest requirements to
    # the `ObjectSpace::WeakMap`, we use it as a default or fallback if there is
    # no better strategy.
    module StrongSecondaryKeys
      class DeletedEntry; end
      private_constant :DeletedEntry

      # Checks if this strategy is usable for the current Ruby version.
      #
      # @return [Bool] always `true` to indicate that this stragegy should be
      #   usable with any Ruby implementation which provides an
      #   `ObjectSpace::WeakMap`.
      def self.usable?
        true
      end

      # @!macro weak_set_method_add
      def add(obj)
        key = @key_map[obj.__id__] ||= Object.new.freeze
        @map[key] = obj
        self
      end

      # @!macro weak_set_method_clear
      def clear
        @map = ObjectSpace::WeakMap.new
        @key_map = {}
        self
      end

      # @!macro weak_set_method_delete_question
      def delete?(obj)
        # When deleting, we still retain the key to avoid having to re-create it
        # when `obj` is re-added to the {Weak::Set} again before the next GC.
        #
        # If `obj` is not added again, the key is eventually removed with our next
        # GC of the `@key_map`.
        key = @key_map[obj.__id__]
        if key && @map.key?(key) && @map[key].equal?(obj)
          # If there is a valid value in the `ObjectSpace::WeakMap` (with a
          # strong object_id key), we replace the value of the strong key with a
          # DeletedEntry marker object. This will cause the key/value entry to
          # vanish from the `ObjectSpace::WeakMap` when the DeletedEntry object
          # is eventually garbage collected.
          @map[key] = DeletedEntry.new
          self
        end
      end

      # @!macro weak_set_method_each
      def each
        return enum_for(__method__) { size } unless block_given?

        @map.values.each do |obj|
          yield(obj) unless DeletedEntry === obj
        end
        self
      end

      # @!macro weak_set_method_include_question
      def include?(obj)
        key = @key_map[obj.__id__]
        value = !!(key && @map.key?(key) && @map[key].equal?(obj))

        auto_prune
        value
      end

      # @!macro weak_set_method_prune
      def prune
        @key_map.each do |id, key|
          @key_map.delete(id) unless @map.key?(key)
        end
        self
      end

      # @!macro weak_set_method_replace
      def replace(enum)
        map = ObjectSpace::WeakMap.new
        key_map = {}
        do_with_enum(enum) do |obj|
          key = key_map[obj.__id__] ||= Object.new.freeze
          map[key] = obj
        end
        @map = map
        @key_map = key_map

        self
      end

      # @!macro weak_set_method_size
      def size
        # Compared to using `ObjectSpace::WeakMap#each_value` like we do in
        # {WeakKeys}, this version is ~12% faster on JRuby < 9.4.6.0
        @map.values.delete_if { |obj| DeletedEntry === obj }.size
      end

      # @!macro weak_set_method_to_a
      def to_a
        @map.values.delete_if { |obj| DeletedEntry === obj }
      end

      private

      # Prune unneeded entries from the `@key_map` Hash if we could remove at
      # least 2000 entries or 20% of the table size (whichever is greater).
      # Since the cost of the GC pass is O(N), we want to make sure that we
      # condition this on overall table size, to avoid O(N^2) CPU costs.
      def auto_prune
        key_map_size = @key_map.size
        cutoff = [2000, (key_map_size * 0.2).ceil].max

        prune if key_map_size - @map.size > cutoff
      end
    end
  end
end
