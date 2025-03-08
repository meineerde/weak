# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

##
module Weak
  class Set
    # This {Weak::Set} strategy targets Ruby < 3.3.0.
    #
    # Its `ObjectSpace::WeakMap` uses weak keys and weak values so that either
    # the key or the value can be independently garbage collected. If either of
    # them vanishes, the entry is removed.
    #
    # The `ObjectSpace::WeakMap` does not allow to explicitly delete entries. We
    # emulate this by setting the garbage-collectible value of a deleted entry
    # to a simple new object. This value will be garbage collected on the next
    # GC run which will then remove the entry. When accessing elements, we
    # delete and filter out these recently deleted entries.
    module WeakKeys
      class DeletedEntry; end
      private_constant :DeletedEntry

      # Checks if this strategy is usable for the current Ruby version.
      #
      # @return [Bool] truethy for Ruby (aka. MRI, aka. YARV), falsey otherwise
      def self.usable?
        RUBY_ENGINE == "ruby"
      end

      # @!macro weak_set_method_add
      def add(obj)
        @map[obj] = obj
        self
      end

      # @!macro weak_set_method_clear
      def clear
        @map = ObjectSpace::WeakMap.new
        self
      end

      # @!macro weak_set_method_delete_question
      def delete?(obj)
        return unless include?(obj)

        # If there is a valid entry in the `ObjectSpace::WeakMap`, we replace
        # the value for the `obj` with a temporary DeletedEntry object. As we do
        # not keep any strong reference to this object, this will cause the
        # key/value entry to vanish from the `ObjectSpace::WeakMap` when the
        # `DeletedEntry` object is eventually garbage collected.
        #
        # This ensures that we don't retain unnecessary entries in the map which
        # we would have to skip over.
        @map[obj] = DeletedEntry.new
        self
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
        !!(@map.key?(obj) && @map[obj].equal?(obj))
      end

      # @!macro weak_set_method_prune
      def prune
        self
      end

      # @!macro weak_set_method_replace
      def replace(enum)
        map = ObjectSpace::WeakMap.new
        do_with_enum(enum) do |obj|
          map[obj] = obj
        end
        @map = map

        self
      end

      # @!macro weak_set_method_size
      def size
        count = 0
        @map.each_value do |obj|
          count = count.succ unless DeletedEntry === obj
        end
        count
      end

      # @!macro weak_set_method_to_a
      def to_a
        @map.values.delete_if { |obj| DeletedEntry === obj }
      end
    end
  end
end
