# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require "weak/map/deletable"

##
module Weak
  class Map
    # @abstract This module implements a common subset of (helper-)methods
    #   for a {Weak::Map} with an `ObjectSpace::WeakMap` with strong keys, i.e.,
    #   {StrongKeys} and {StrongSecondaryKeys}.
    module AbstractStrongKeys
      include Deletable

      # @!macro weak_map_method_keys
      def keys
        each_key.to_a
      end

      # @!macro weak_map_method_size
      def size
        each_key.count
      end

      # @!macro weak_map_method_values
      def values
        each_value.to_a
      end

      private

      # This method is called during {#_get}. It generally needs to be
      # overwritten in a "sub"-module to automatically cleanup any internal
      # data. The implemented `auto_prune` method should quickly check if a
      # prune is necessary and then either call the `prune` method or return.
      #
      # @return [void]
      def auto_prune
      end

      def _delete(id)
        if have?(@keys[id])
          @keys[id] = DeletedEntry.new
          has_key = true
        end

        raw_value = @values[id]
        if have?(raw_value)
          @values[id] = DeletedEntry.new
          return value!(raw_value) if has_key
        end

        yield
      end

      def _get(id)
        raw_value = @values[id]
        has_key = have?(@keys[id])

        auto_prune
        if have?(raw_value)
          if has_key
            # We have a stored key AND a stored value. This is the positive case
            # where we return the stored value
            value!(raw_value)
          else
            # Here, we have a stored value but a missing key which likely was
            # garbage collected. Thus, we explicitly delete the now invalid
            # value and act as if it was already removed.
            @values[id] = DeletedEntry.new
            yield
          end
        else
          # Here, we do not have a stored value (e.g. because it was garbage
          # collected or is generally absent). If we have found a valid key
          # earlier, this key is thus invalid and we explicitly delete it.
          @keys[id] = DeletedEntry.new if has_key
          yield
        end
      end
    end
  end
end
