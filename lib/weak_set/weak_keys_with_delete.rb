# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

##
class WeakSet
  # This WeakSet strategy targets Ruby >= 3.3.0.
  # Older Ruby versions require additional indirections implemented in
  # {WeakSet::WeakKeys}:
  #
  # - https://bugs.ruby-lang.org/issues/19561
  #
  # Ruby's ObjectSpace::WeakMap uses weak keys and weak values so that either
  # the key or the value can be independently garbage collected. If either of
  # them vanishes, the entry is removed.
  #
  # The WeakMap also allows to delete entries. This allows us to directly use
  # the WeakMap as a storage the same way a `Set` uses a `Hash` object object as
  # storage.
  module WeakKeysWithDelete
    # Checks if this strategy is usable for the current Ruby version.
    #
    # @return [Bool] truethy for Ruby (aka. MRI, aka. YARV) >= 3.3.0,
    #   falsey otherwise
    def self.usable?
      RUBY_ENGINE == "ruby" &&
        ObjectSpace::WeakMap.instance_methods.include?(:delete)
    end

    # Initialize the weak map
    # @return [void]
    def initialize
      @map = ObjectSpace::WeakMap.new
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

    # @!macro weak_set_method_size
    def size
      @map.size
    end

    # @!macro weak_set_method_to_a
    def to_a
      @map.keys
    end

    private

    def cleared
      original_map, @map = @map, ObjectSpace::WeakMap.new
      yield
    rescue Exception
      @map = original_map
      raise
    end
  end
end
