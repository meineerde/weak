# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require "weak/map/weak_keys_with_delete"
require "weak/map/weak_keys"
require "weak/map/strong_keys"
require "weak/map/strong_secondary_keys"
require "weak/undefined"

##
module Weak
  # `Weak::Map` behaves similar to a `Hash` or an `ObjectSpace::WeakMap` in Ruby
  # (aka. MRI, aka. YARV). Both keys and values are weakly referenceed, allowing
  # either of them to be independently garbage collected. If either the key or
  # the value of a pair is garbage collected, the entire pair will be removed
  # from the `Weak::Map`.
  #
  # {Weak::Map} uses `ObjectSpace::WeakMap` as storage, so you must note the
  # following points:
  #
  # - Equality of both keys and values is determined strictly by their object
  #    identity instead of `Object#eql?` or `Object#hash` as the `Hash` class
  #    does by default.
  # - Keys and values can be freely changed without affecting the map.
  # - Keys and values can be freely garbage collected by Ruby. A key-value pair
  #   will be removed from the map automatically if theoer the key or the value
  #   is garbage collected.
  # - The order of key-value pairs in the map is non-deterministic. Insertion
  #   order is not preserved.
  #
  # Note that {Weak::Map} is not inherently thread-safe. When accessing a
  # {Weak::Map} from multiple threads or fibers, you MUST use a mutex or another
  # locking mechanism.
  #
  # ## Implementation Details
  #
  # The various Ruby implementations and versions show quite diverse behavior in
  # their respective `ObjectSpace::WeakMap` implementations. To provide a
  # unified behavior on all implementations, we use different storage
  # strategies:
  #
  # - Ruby (aka. MRI, aka. YARV) >= 3.3 has an `ObjectSpace::WeakMap` with weak
  #   keys and weak values and the ability to delete elements from it. This
  #   allows a straight-forward implementation in
  #   {Weak::Map::WeakKeysWithDelete}.
  # - Ruby (aka. MRI, aka. YARV) < 3.3 has an `ObjectSpace::WeakMap` with weak
  #   keys and weak values but does not allow to directly delete entries. We
  #   emulate this with special garbage-collectible values in
  #   {Weak::Map::WeakKeys}.
  # - JRuby >= 9.4.6.0 and TruffleRuby >= 22 have an `ObjectSpace::WeakMap` with
  #   strong keys and weak values. To allow both keys and values to be garbage
  #   collected, we can't use the actual object as a key in a single
  #   `ObjectSpace::WeakMap`. Instead, we use a sepate `WeakMap` for keys and
  #   values which in turn use the key's `object_id` as a key. As
  #   these `ObjectSpace::WeakMap` objects also do not allow to delete entries,
  #   we emulate deletion with special garbage-collectible values as above. This
  #   is implemented in {Weak::Map::StrongKeys}.
  # - JRuby < 9.4.6.0 has a similar `ObjectSpace::WeakMap` as newer JRuby
  #   versions with strong keys and weak values. However generally in JRuby,
  #   Integer values (including object_ids) can have multiple different object
  #   representations in memory and are not necessarily equal to each other when
  #   used as keys in an `ObjectSpace::WeakMap`. As a workaround we use an
  #   indirect implementation with a secondary lookup table for the map keys in
  #   for both stored keys and values {Weak::Map::StrongSecondaryKeys}.
  #
  # The required strategy is selected automatically based in the running
  # Ruby. The external behavior is the same for all implementations.
  #
  # @example
  #   require "weak/map"
  #
  #   map = Weak::Map.new
  #   map[:key] = "a value"
  #   map[:key]
  #   # => "a value"
  class Map
    include Enumerable

    # We try to find the best implementation strategy based on the current Ruby
    # engine and version. The chosen `STRATEGY` is included into the {Weak::Map}
    # class.
    STRATEGY = [
      Weak::Map::WeakKeysWithDelete,
      Weak::Map::WeakKeys,
      Weak::Map::StrongKeys,
      Weak::Map::StrongSecondaryKeys
    ].find(&:usable?)

    include STRATEGY

    ############################################################################
    # Here follows the documentation of strategy-specific methods which are
    # implemented in one of the include modules depending on the current Ruby.

    # @!macro _note_object_equality
    #   @note {Weak::Map} does not test member equality with `==` or `eql?`.
    #     Instead, it always checks strict object equality, so that, e.g.,
    #     different String keys are not considered equal, even if they may
    #     contain the same content.
    #
    # @!macro weak_map_accessor_read
    #   @param key [Object] the key for the requested value
    #   @return [Object] the value associated with the given `key`, if found. If
    #     `key` is not found, returns the default value, i.e. the value returned
    #     by the default proc (if defined) or the `default` value (which is
    #     initially `nil`.)
    #   @!macro _note_object_equality

    # @!macro weak_map_accessor_write
    #   Associates the given `value` with the given `key`; returns `value`. If
    #   the given `key` exists, replaces its value with the given `value`.
    #
    #   @param key [Object] the key for the set key-value pair
    #   @param value [Object] the value of the set key-value pair
    #   @return [Object] the given `value`
    #   @!macro _note_object_equality

    # @!macro weak_map_method_clear
    #   Removes all elements and returns `self`
    #
    #   @return [self]

    # @!macro weak_map_method_delete
    #   Deletes the key-value pair and returns the value from `self` whose key
    #   is equal to `key`. If the key is not found, it returns `nil`. If the
    #   optional block is given and the key is not found, pass in the key and
    #   return the result of the block.
    #
    #   @param key [Object] the key to delete
    #   @return [Object, nil] the value associated with the given `key`, or the
    #     result of the optional block if given the key was not found, or `nil`
    #     if the key was not found and no block was given.
    #   @yield [key]
    #   @yieldparam key [Object] the given `key` if it was not part of the map
    #   @!macro _note_object_equality

    # @!macro weak_map_method_each_pair
    #   Calls the given block once for each live key in `self`, passing the key
    #   and value as parameters. Returns the weak map itself.
    #
    #   If no block is given, an `Enumerator` is returned instead.
    #
    #   @yield [key, value] calls the given block once for each key in `self`
    #   @yieldparam key [Object] the key of the current key-value pair
    #   @yieldparam value [Object] the value of the current key-value pair
    #   @return [self, Enumerator] `self` if a block was given or an
    #     `Enumerator` if no block was given.

    # @!macro weak_map_method_each_key
    #   Calls the given block once for each live key in `self`, passing the key
    #   as a parameter. Returns the weak map itself.
    #
    #   If no block is given, an `Enumerator` is returned instead.
    #
    #   @yield [key] calls the given block once for each key in `self`
    #   @yieldparam key [Object] the key of the current key-value pair
    #   @return [self, Enumerator] `self` if a block was given or an
    #     `Enumerator` if no block was given.

    # @!macro weak_map_method_each_value
    #   Calls the given block once for each live key `self`, passing the live
    #   value associated with the key as a parameter. Returns the weak map
    #   itself.
    #
    #   If no block is given, an `Enumerator` is returned instead.
    #
    #   @yield [value] calls the given block once for each key in `self`
    #   @yieldparam value [Object] the value of the current key-value pair
    #   @return [self, Enumerator] `self` if a block was given or an
    #     `Enumerator` if no block was given.

    # @!macro weak_map_method_fetch
    #   Returns a value from the hash for the given `key`. If the key can't be
    #   found, there are several options: With no other arguments, it will raise
    #   a `KeyError` exception; if `default` is given, then that value will be
    #   returned; if the optional code block is specified, then it will be
    #   called and its result returned.
    #
    #   @param key [Object] the key for the requested value
    #   @param default [Object] a value to return if there is no value at `key`
    #     in the hash
    #   @yield [key] if no value was set at `key`, no `default` value was given,
    #     and a block was given, we call the block and return its value
    #   @yieldparam key [String] the given `key`
    #   @return [Object] the value for the given `key` if present in the map. If
    #     the key was not found, we return the `default` value or the value of
    #     the given block.
    #   @raise [KeyError] if the key can not be found and no block or `default`
    #     value was provided
    #   @!macro _note_object_equality

    # @!macro weak_map_method_include_question
    #   @param key [Object] a possible key
    #   @return [Bool] `true` if the given key is included in `self` and has an
    #     associated live value, `false` otherwise
    #   @!macro _note_object_equality

    # @!macro weak_map_method_keys
    #   @return [Array] an `Array` containing all keys of the map for which we
    #     have a valid value. Keys with garbage-collected values are excluded.
    #   @note In contrast to a `Hash`, `Weak::Map`s do not necessarily retain
    #     insertion order.
    #   @see Weak::Map#values

    # @!macro weak_map_method_prune
    #   Cleanup data structures from the map to remove data associated with
    #   deleted or garbage collected keys and/or values. This method may be
    #   called automatically for some {Weak::Map} operations.
    #
    #   @return [self]

    # @!macro weak_map_method_size
    #   @return [Integer] the number of live key-value pairs in `self`

    # @!macro weak_map_method_values
    #   @return [Array] an `Array` containing all values of the map for which we
    #     have a valid key. Values with garbage-collected keys are excluded.
    #   @note In contrast to a `Hash`, `Weak::Map`s do not necessarily retain
    #     insertion order.
    #   @see Weak::Map#keys

    ############################################################################

    # @!method [](key)
    #   @!macro weak_map_accessor_read

    # @!method []=(key, value)
    #   @!macro weak_map_accessor_write

    # @!method clear
    #   @!macro weak_map_method_clear

    # @!method delete(key = UNDEFINED)
    #   @!macro weak_map_method_delete

    # @!method each_pair
    #   @!macro weak_map_method_each_pair

    # @!method each_key
    #   @!macro weak_map_method_each_key

    # @!method each_value
    #   @!macro weak_map_method_each_value

    # @!method fetch(key, default = UNDEFINED, &block)
    #   @!macro weak_map_method_fetch

    # @!method include?(key)
    #   @!macro weak_map_method_include_question

    # @!method keys
    #   @!macro weak_map_method_keys

    # @!method prune
    #   @!macro weak_map_method_prune

    # @!method size
    #   @!macro weak_map_method_size

    # @!method values
    #   @!macro weak_map_method_values

    ############################################################################

    # The same value as `Set::InspectKey`. This is used as a key in
    # `Thread.current` in {#inspect} to resolve object loops.
    INSPECT_KEY = :__inspect_key__
    private_constant :INSPECT_KEY

    # @param maps [Array<Weak::Map, Hash, #to_hash>] a list of maps which should
    #   be merged into the new {Weak::Map}
    # @return [Weak::Map] a new {Weak::Map} object populated with the given
    #   objects, if any. With no argument, returns a new empty {Weak::Map}.
    # @example
    #   hash = {foo: 0, bar: 1, baz: 2}
    #   Weak::Map[hash]
    #   # => #<Weak::Map {:foo=>0, :bar=>1, :baz=>2}>
    def self.[](*maps)
      Weak::Map.new.merge!(*maps)
    end

    # Returns a new empty Weak::Map object.
    #
    # The initial default value and initial default proc for the new hash depend
    # on which form above was used.
    #
    # If neither an `default_value` nor a block is given, initializes both the
    # default value and the default proc to nil:
    #
    #     map = Weak::Map.new
    #     map.default               # => nil
    #     map.default_proc          # => nil
    #
    # If a `default_value` is given but no block is given, initializes the
    # default value to the given `default_value` and the default proc to nil:
    #
    #     map = Hash.new(false)
    #     map.default               # => false
    #     map.default_proc          # => nil
    #
    # If a block is given but no `default_value`, stores the block as the
    # default proc and sets the default value to nil:
    #
    #     map = Hash.new { |map, key| "Default value for #{key}" }
    #     map.default              # => nil
    #     map.default_proc.class   # => Proc
    #     map[:nosuch]             # => "Default value for nosuch"
    #
    # If both a block and a `default_value` are given, raises an `ArgumentError`
    #
    # @param default_value (see #default_value=)
    def initialize(default_value = UNDEFINED, &default_proc)
      clear

      if UNDEFINED.equal?(default_value)
        @default_value = nil
        @default_proc = default_proc
      elsif block_given?
        raise ArgumentError, "wrong number of arguments (given 1, expected 0)"
      else
        @default_value = default_value
        @default_proc = nil
      end
    end

    alias_method :each, :each_pair
    alias_method :has_key?, :include?
    alias_method :key?, :include?
    alias_method :member?, :include?
    alias_method :length, :size
    alias_method :store, :[]

    # {Weak::Map} objects can't be frozen since this is not enforced by the
    # underlying `ObjectSpace::WeakMap` implementation. Thus, we try to signal
    # this by not actually setting the `frozen?` flag and ignoring attempts to
    # freeze us with just a warning.
    #
    # @param freeze [Bool, nil] ignored; we always behave as if this is false.
    #   If this is set to a truethy value, we emit a warning.
    # @return [Weak::Set] a new `Weak::Map` object containing the same elements
    #   as `self`
    def clone(freeze: false)
      warn("Can't freeze #{self.class}") if freeze

      super(freeze: false)
    end

    # This method does nothing as we always compare elements by their object
    # identity.
    #
    # @return [self]
    def compare_by_identity
      self
    end

    # @return [true] always `true` since we always compare elements by their
    #   object identity
    def compare_by_identity?
      true
    end

    # Returns the default value for the given `key`. The returned value will be
    # determined either by the default proc or by the default value. With no
    # argument, returns the current default value (initially `nil`). If `key` is
    # given, returns the default value for `key`, regardless of whether that key
    # exists.
    #
    # @param key [Object] if given, we return the default value for this key
    # @return [Object] the default value for `key` if given, or weak map's
    #   default value
    def default(key = UNDEFINED)
      if UNDEFINED.equal? key
        @default_value
      else
        _default(key)
      end
    end

    # Sets the default value to `default_value` and clears the {#default_proc};
    # returns `default_value`.
    #
    # @param default_value [Object] the new default value which will be returned
    #   when accessing a non-existing key
    # @return [Object] the given `default_value`
    def default=(default_value)
      @default_proc = nil
      @default_value = default_value
    end

    # @return [Proc, nil] the default proc for `self`
    def default_proc
      @default_proc
    end

    # Sets the default proc for self to `proc` and clears the {#default} value.
    #
    # @param proc [Proc, #to_proc nil] a `Proc` which can be called with two
    #   arguments: the map and the rquested non-exiting key. The proc is
    #   expected to return the default value for the key. Whe giving `nil`, the
    #   default proc is cleared.
    # @return [Proc, nil] the new default proc
    # @raise [TypeError] if the given `proc` can not be converted to a `Proc`.
    def default_proc=(proc)
      @default_value = nil
      return @default_proc = nil if proc.nil?

      if Proc === proc
        default_proc = proc
      elsif proc.respond_to?(:to_proc)
        default_proc = proc.to_proc
        unless Proc === default_proc
          raise TypeError, "can't convert #{proc.class} to Proc " \
            "(#{proc.class}#to_proc gives #{default_proc.class})"
        end
      else
        raise TypeError, "no implicit conversion of #{proc.class} into Proc"
      end

      if default_proc.lambda?
        arity = default_proc.arity
        if arity != 2 && (arity >= 0 || arity < -3)
          arity = -arity - 1 if arity < 0
          raise TypeError, "default_proc takes two arguments (2 for #{arity})"
        end
      end
      @default_proc = default_proc

      proc
    end

    # Deletes every key-value pair from `self` for which the given block
    # evaluates to a truthy value.
    #
    # If no block is given, an `Enumerator` is returned instead.
    #
    # @yield [key, value] calls the given block once for each key in the map
    # @yieldparam key [Object] a key
    # @yieldparam value [Object] the corresponding value
    # @return [Enumerator, self] `self` if a block was given or an `Enumerator`
    #   if no block was given.
    # @see reject!
    def delete_if(&block)
      return enum_for(__method__) { size } unless block_given?

      each do |key, value|
        delete(key) if yield(key, value)
      end
      self
    end

    # @return [Boolean] `true` if `self` contains no elements
    def empty?
      size == 0
    end

    # {Weak::Set} objects can't be frozen since this is not enforced by the
    # underlying `ObjectSpace::WeakMap` implementation. Thus, we try to signal
    # this by not actually setting the `frozen?` flag and ignoring attempts to
    # freeze us with just a warning.
    #
    # @return [self]
    def freeze
      warn("Can't freeze #{self.class}")
      self
    end

    # @param value [Object] a value to check
    # @return [Bool] `true` if `value` is a value in `self`, `false` otherwise
    #
    # @!macro _note_object_equality
    def has_value?(value)
      id = value.__id__
      each_value.any? { |v| v.__id__ == id }
    end
    alias_method :value?, :has_value?

    # @return [String] a string containing a human-readable representation of
    #   the weak set, e.g.,
    #   `"#<Weak::Map {key1 => value1, key2 => value2, ...}>"`
    def inspect
      object_ids = (Thread.current[INSPECT_KEY] ||= [])
      return "#<#{self.class} {...}>" if object_ids.include?(object_id)

      object_ids << object_id
      begin
        elements = to_a.sort_by! { |k, _v| k.__id__ }.to_h
        "#<#{self.class} #{elements}>"
      ensure
        object_ids.pop
      end
    end
    alias_method :to_s, :inspect

    # Deletes every key-value pair from `self` for which the given block
    # evaluates to a falsey value.
    #
    # If no block is given, an `Enumerator` is returned instead.
    #
    # @yield [key, value] calls the given block once for each key in the map
    # @yieldparam key [String] a hash key
    # @yieldparam value [Object] the corresponding hash value
    # @return [Enumerator, self] `self` if a block was given, an `Enumerator`
    #  if no block was given.
    # @see select!
    def keep_if(&block)
      return enum_for(__method__) { size } unless block_given?

      each do |key, value|
        delete(key) unless yield(key, value)
      end
      self
    end

    # Returns the new {Weak::Map} formed by merging each of `other_maps` into a
    # copy of `self`.
    #
    # Each argument in `other_maps` must be either a {Weak::Map}, a Hash object
    # or must be transformable to a Hash by calling `each_hash` on it.
    #
    # With arguments and no block:
    #
    #   - Returns a new {Weak::Map}, after the given maps are merged into a copy
    #     of `self`.
    #   - The given maps are merged left to right.
    #   - Each duplicate-key entry’s value overwrites the previous value.
    #
    # Example:
    #
    #     map = Weak::Map.new
    #     map[:foo] = 0
    #     map[:bar] = 1
    #
    #     h1 = {baz: 3, bar: 4}
    #     h2 = {bam: 5, baz: 6}
    #     map.merge(h1, h2)
    #     # => #<Weak::Map {:foo=>0, :bar=>4, :baz=>6, :bam=>5}
    #
    # With arguments and a block:
    #
    #   - Returns `self`, after the given maps are merged.
    #   - The given maps are merged left to right.
    #   - For each duplicate key:
    #     - Calls the block with the key and the old and new values.
    #     - The block’s return value becomes the new value for the entry.
    #   - The block should only return values which are otherwise strongly
    #     referenced to ensure that the value is not immediately
    #     garbage-collected.
    #
    # Example:
    #
    #     map = Weak::Map.new
    #     map[:foo] = 0
    #     map[:bar] = 1
    #
    #     h1 = {baz: 3, bar: 4}
    #     h2 = {bam: 5, baz: 6}
    #     map.merge(h1, h2) { |key, old_value, new_value| old_value + new_value }
    #     # => #<Weak::Map {:foo=>0, :bar=>5, :baz=>9, :bam=>5}
    #
    # With no arguments:
    #
    #   - Returns a copy of `self`.
    #   - The block, if given, is ignored.
    #
    # @param other_maps [Array<Weak::Map, Hash, #to_hash>] a list of maps which
    #   should be merged into a copy of `self`
    # @yield [key, old_value, new_value] If `self` already contains a value for
    #   a key, we yield the key, the old value from `self` and the new value
    #   from the given map and use the value returned from the block as the new
    #   value to be merged.
    # @yieldparam key [Object] the conflicting key
    # @yieldparam old_value [Object] the existing value from `self`
    # @yieldparam old_value [Object] the new value from one of the given
    #   `other_maps`
    # @return [Weak::Map] a new weak map containing the merged pairs
    #
    # @!macro _note_object_equality
    def merge(*other_maps, &block)
      dup.merge!(*other_maps, &block)
    end

    # @!visibility private
    def pretty_print(pp)
      pp.group(1, "#<#{self.class}", ">") do
        pp.breakable
        pp.pp to_a.sort_by! { |k, _v| k.__id__ }.to_h
      end
    end

    # @!visibility private
    def pretty_print_cycle(pp)
      pp.text "#<#{self.class} {#{"..." unless empty?}}>"
    end

    # Deletes every key-value pair from `self` for which the given block
    # evaluates to a truethy value.
    #
    # Equivalent to {#delete_if}, but returns `nil` if no changes were made.
    #
    # If no block is given, an `Enumerator` is returned instead.
    #
    # @yield [key, value] calls the given block once for each key in the map
    # @yieldparam key [Object] a key
    # @return [Enumerator, self, nil] `self` if a block was given and some
    #   element(s) were deleted, `nil` if a block was given but no keys were
    #   deleted, or an `Enumerator` if no block was given.
    # @see #delete_if
    def reject!(&block)
      return enum_for(__method__) { size } unless block_given?

      deleted_anything = false
      each do |key, value|
        next unless yield(key, value)

        delete(key)
        deleted_anything = true
      end

      self if deleted_anything
    end

    # Replaces the contents of `self` with the contents of the given Hash-like
    # object and returns `self`.
    #
    # If the given `map` defines a {#default} value or {#default_proc}, this
    # will also replace the respective seting in `self`.
    #
    # @param map (see #_implicit)
    # @return [self]
    # @example
    #     map = Weak::Map[a: 1, b: 3, c: 1] #=> #<Weak::Map {a: 1, b: 3, c: 1}>
    #     map.replace({x: :y})              #=> #<Weak::Map {x: :y}>
    #     map                               #=> #<Weak::Map {x: :y}>
    def replace(map)
      initialize_copy(_implicit(map))
    end

    # Deletes every key-value pair from `self` for which the given block
    # evaluates to a falsey value.
    #
    # Equivalent to {#keep_if}, but returns `nil` if no changes were made.
    #
    # If no block is given, an `Enumerator` is returned instead.
    #
    # @yield [key, value] calls the given block once for each key in the map
    # @yieldparam key [Object] a key
    # @yieldparam value [Object] the corresponding value
    # @return [Enumerator, self, nil] `self` if a block was given and some
    #   element(s) were deleted, `nil` if a block was given but nothing was
    #   deleted, or an `Enumerator` if no block was given.
    # @see keep_if
    def select!(&block)
      return enum_for(__method__) { size } unless block_given?

      deleted_anything = false
      each do |key, value|
        next if yield(key, value)

        delete(key)
        deleted_anything = true
      end

      self if deleted_anything
    end
    alias_method :filter!, :select!

    # Merges each of `other_maps` into `self`; returns `self`.
    #
    # Each argument in `other_maps` must be either a {Weak::Map}, a Hash object
    # or must be transformable to a Hash by calling `each_hash` on it.
    #
    # With arguments and no block:
    #
    #   - Returns self, after the given maps are merged into it.
    #   - The given maps are merged left to right.
    #   - Each duplicate-key entry’s value overwrites the previous value.
    #
    # Example:
    #
    #     map = Weak::Map.new
    #     map[:foo] = 0
    #     map[:bar] = 1
    #
    #     h1 = {baz: 3, bar: 4}
    #     h2 = {bam: 5, baz: 6}
    #     map.update(h1, h2)
    #     # => #<Weak::Map {:foo=>0, :bar=>4, :baz=>6, :bam=>5}
    #
    # With arguments and a block:
    #
    #   - Returns `self`, after the given maps are merged.
    #   - The given maps are merged left to right.
    #   - For each duplicate key:
    #     - Calls the block with the key and the old and new values.
    #     - The block’s return value becomes the new value for the entry.
    #   - The block should only return values which are otherwise strongly
    #     referenced to ensure that the value is not immediately
    #     garbage-collected.
    #
    # Example:
    #
    #     map = Weak::Map.new
    #     map[:foo] = 0
    #     map[:bar] = 1
    #
    #     h1 = {baz: 3, bar: 4}
    #     h2 = {bam: 5, baz: 6}
    #     map.update(h1, h2) { |key, old_value, new_value| old_value + new_value }
    #     # => #<Weak::Map {:foo=>0, :bar=>5, :baz=>9, :bam=>5}
    #
    # With no arguments:
    #
    #   - Returns `self`.
    #   - The block, if given, is ignored.
    #
    # @param other_maps [Array<Weak::Map, Hash, #to_hash>] a list of maps which
    #    should be merged into `self`
    # @yield [key, old_value, new_value] If `self` already contains a value for
    #   a key, we yield the key, the old value from `self` and the new value
    #   from the given map and use the value returned from the block as the new
    #   value to be merged.
    # @yieldparam key [Object] the conflicting key
    # @yieldparam old_value [Object] the existing value from `self`
    # @yieldparam old_value [Object] the new value from one of the given
    #   `other_maps`
    # @return [self]
    #
    # @!macro _note_object_equality
    def update(*other_maps)
      if block_given?
        missing = Object.new

        other_maps.each do |map|
          _implicit(map).each_pair do |key, value|
            old_value = fetch(key, missing)
            value = yield(key, old_value, value) unless missing == old_value
            self[key] = value
          end
        end
      else
        other_maps.each do |map|
          _implicit(map).each_pair do |key, value|
            self[key] = value
          end
        end
      end

      self
    end
    alias_method :merge!, :update

    # @return [Array] a new `Array` of 2-element `Array` objects; each nested
    #   `Array` contains a key-value pair from self
    def to_a
      to_h.to_a
    end

    # @yield [key, value] When a block is given, returns a new Hash object whose
    #   content is based on the block; the block should return a 2-element Array
    #   object specifying the key-value pair to be included in the returned
    #   Hash.
    # @yieldparam key [Object] the key of the current key-value pair
    # @yieldparam value [Object] the value of the current key-value pair
    # @return [Hash] a new `Hash` which considers object identity for keys which
    #   contains the key-value pairs in `self`.
    def to_h(&block)
      hash = {}.compare_by_identity
      if block_given?
        each do |key, value|
          map = yield(key, value)
          ary = Array.try_convert(map)
          unless ary
            raise TypeError, "wrong element type #{map.class} (expected array)"
          end
          unless ary.size == 2
            raise ArgumentError, "element has wrong array length " \
              "(expected 2, was #{ary.size})"
          end

          hash[ary[0]] = ary[1]
        end
      else
        each do |key, value|
          hash[key] = value
        end
      end

      hash
    end

    # Returns a new `Array` containing values for the given keys:
    #
    #     map = Weak::Map[foo: 0, bar: 1, baz: 2]
    #     map.values_at(:baz, :foo)
    #     # => [2, 0]
    #
    # The default values are returned for any keys that are not found:
    #
    #     map.values_at(:hello, :foo)
    #     # => [nil, 0]
    #
    # @param keys [Array<Object>] a list of keys
    # @return [Array] an `Array` containing the values for the given keys if
    #   present or the default value if not. The order of the given `keys` is
    #   preserved.
    def values_at(*keys)
      keys.map { |key| self[key] }
    end

    private

    # Callback method which is called on the new object during `dup` or `clone`
    def initialize_copy(orig)
      initialize
      merge!(orig)
      if orig.default_proc
        self.default_proc = orig.default_proc
      else
        self.default = orig.default
      end

      self
    end

    def _default(key)
      @default_proc ? default_proc.call(self, key) : @default_value
    end

    def _fetch_default(key, default = UNDEFINED)
      have_default = !UNDEFINED.equal?(default)

      if block_given?
        warn("warning: block supersedes default value argument") if have_default
        yield(key)
      elsif have_default
        default
      else
        raise KeyError.new(
          "key not found: #{key.inspect}",
          receiver: self,
          key: key
        )
      end
    end

    # @param map [Weak::Map, Hash, #to_hash] a {Weak::Map} or a Hash object or
    #   an object which can be converted to a `Hash` by calling `to_hash` on it
    # @return [Weak::Map, Hash] either a `Weak::Map` or a `Hash` object
    #   converted from the given `map`
    # @raise [TypeError] if the given `map` is not a {Weak::Map} and not a
    #   `Hash`, and could not ge converted to a Hash
    def _implicit(map)
      if Weak::Map === map || ::Hash === map
        map
      elsif (hash = ::Hash.try_convert(map))
        hash
      else
        raise TypeError, "no implicit conversion of #{map.class} into #{self.class}"
      end
    end
  end
end
