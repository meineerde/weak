# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

##
module Weak
  class Set
    # This {Weak::Set} strategy targets Ruby >= 3.3.0.
    # Older Ruby versions require additional indirections implemented in
    # {Weak::Set::WeakKeys}:
    #
    # - https://bugs.ruby-lang.org/issues/19561
    #
    # Ruby's `ObjectSpace::WeakMap` uses weak keys and weak values so that
    # either the key or the value can be independently garbage collected. If
    # either of them vanishes, the entry is removed.
    #
    # The `ObjectSpace::WeakMap` also allows to delete entries. This allows us
    # to directly use the `ObjectSpace::WeakMap` as a storage object.
    module WeakKeysWithDelete
      # Checks if this strategy is usable for the current Ruby version.
      #
      # @return [Bool] truethy for Ruby (aka. MRI, aka. YARV) >= 3.3.0,
      #   falsey otherwise
      def self.usable?
        RUBY_ENGINE == "ruby" &&
          ObjectSpace::WeakMap.instance_methods.include?(:delete)
      end

      # @!macro weak_set_method_add
      def add(obj)
        @map[obj] = true
        self
      end

      # @!macro weak_set_method_clear
      def clear
        @map = ObjectSpace::WeakMap.new
        self
      end

      # @!macro weak_set_method_delete_question
      def delete?(obj)
        # `ObjectSpace::WeakMap#delete` returns the value if it was removed. As
        # we set it to true, `ObjectSpace::WeakMap#delete` returns either true
        # or nil here.
        self if @map.delete(obj)
      end

      # @!macro weak_set_method_each
      def each(&block)
        return enum_for(__method__) { size } unless block_given?

        @map.keys.each(&block)
        self
      end

      # @!macro weak_set_method_include_question
      def include?(obj)
        @map.key?(obj)
      end

      # @!macro weak_set_method_prune
      def prune
        self
      end

      # @!macro weak_set_method_replace
      def replace(enum)
        map = ObjectSpace::WeakMap.new
        do_with_enum(enum) do |obj|
          map[obj] = true
        end
        @map = map

        self
      end

      # @!macro weak_set_method_size
      def size
        @map.size
      end

      # @!macro weak_set_method_to_a
      def to_a
        @map.keys
      end
    end
  end
end
