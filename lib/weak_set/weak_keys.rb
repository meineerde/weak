# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

##
class WeakSet
  # This WeakSet implementation targets Ruby < 3.3.0.
  #
  # Its ObjectSpace::WeakMap uses weak keys and weak values so that either the
  # key or the value can be independently garbage collected. If either of them
  # vanishes, the entry is removed.
  #
  # The WeakMap does not allow to explicitly delete entries. We emulate this by
  # setting the garbage-collectible value of a deleted entry to a simple new
  # object. This value will be garbage collected on the next GC run which will
  # then remove the entry. When accessing elements, we delete and filter out
  # these recently deleted entries.
  module WeakKeys
    class DeletedEntry; end
    private_constant :DeletedEntry

    # Initialize the weak map
    # @return [void]
    def initialize
      @map = ObjectSpace::WeakMap.new
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

      # If there is a valid entry in the WeakMap, we replace the value for the
      # obj with a temporary DeletedEntry object. As we do not keep any strong
      # reference to this object, this will cause the key/value entry to vanish
      # from the WeakMap when the DeletedEntry object is eventually garbage
      # collected.
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
