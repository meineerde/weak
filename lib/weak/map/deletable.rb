# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

##
module Weak
  class Map
    # Utility methods used in {Weak::Map} strategies to emulate deletion when
    # the `ObjectSpace:WeakMap` does not directly allow to delete elements.
    module Deletable
      # A class to create objects from to mark deleted entries. These objects
      # can be garbage collected. When reading values, we handle DeletedEntry
      # instances the same way we would handle `nil` values.
      # @see #mising?
      class DeletedEntry; end
      private_constant :DeletedEntry

      # A special marker value to store `nil` in the WeakMap. We use this
      # constant to distinguish the user-provided `nil` value (which is stored
      # as `NIL`) from the absent value.
      NIL = Object.new
      private_constant :NIL

      private

      # Checks if an object gathered from an `ObjectSpace::WeakMap` is present,
      # i.e., if it is not `missing?`
      #
      # @param obj [Object] an object to check
      # @return [Bool] `true` if the `obj` is a present value, i.e. it is
      #   neither `nil` nor a `DeletedEntry`; false otherwise
      def have?(obj)
        !missing?(obj)
      end

      # Checks if an object gathered from an `ObjectSpace::WeakMap` is missing.
      # It is missing if it is either `nil` (if no value was present in the map)
      # or if it is a `DeletedEntry` and was thus marked as deleted.
      #
      # The allowed `nil` value is represented with the special `NIL` constant
      # which is not `missing?`.
      #
      # @param obj [Object] an object to check
      # @return [Bool] `true` if the `obj` is absent, i.e. it is either `nil`
      #   or a `DeletedEntry`; false otherwise
      def missing?(obj)
        obj.nil? || DeletedEntry === obj
      end

      # Get the final value for a retreived raw value. This convertes the
      # special `NIL` value back to `nil`.
      # @param obj [Object, NIL] an object retreived from an
      #   `ObjectSpace::WeakMap`
      # @return [Object, nil] the object or `nil` if `NIL` was given.
      def value!(obj)
        NIL.equal?(obj) ? nil : obj
      end
    end

    private_constant :Deletable
  end
end
