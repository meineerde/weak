# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require "set"

require_relative "set/weak_keys_with_delete"
require_relative "set/weak_keys"
require_relative "set/strong_keys"
require_relative "set/strong_secondary_keys"

##
module Weak
  # This library provides the `Weak::Set` class. It behaves similar to the
  # `::Set` class of the Ruby standard library, but all values are only weakly
  # referenced. That way, all values can be garbage collected and silently
  # removed from the set unless they are still referenced from some other live
  # object.
  #
  # {Weak::Set} uses `ObjectSpace::WeakMap` as storage, so you must note the
  # following points:
  #
  # - Equality of elements is determined strictly by their object identity
  #   instead of `Object#eql?` or `Object#hash` as the Set does by default.
  # - Elements can be freely changed without affecting the set.
  # - All elements can be freely garbage collected by Ruby. They will be removed
  #   from the set automatically.
  # - The order of elements in the set is non-deterministic. Insertion order is
  #   not preserved.
  #
  # Note that {Weak::Set} is not inherently thread-safe. When accessing a
  # {Weak::Set} from multiple threads or fibers, you MUST use a mutex or another
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
  #   {Weak::Set::WeakKeysWithDelete}.
  # - Ruby (aka. MRI, aka. YARV) < 3.3 has an `ObjectSpace::WeakMap` with weak
  #   keys and weak values but does not allow to directly delete entries. We
  #   emulate this with special garbage-collectible values in
  #   {Weak::Set::WeakKeys}.
  # - JRuby >= 9.4.6.0 and TruffleRuby >= 22 have an `ObjectSpace::WeakMap` with
  #   strong keys and weak values. To allow a entries in an
  #   `ObjectSpace::WeakMap` to be garbage collected, we can't use the actual
  #   object as a key. Instead, we use the element's `object_id` as a key. As
  #   these `ObjectSpace::WeakMap` objects also do not allow to delete entries,
  #   we emulate deletion with special garbage-collectible values as above. This
  #   is implemented in {Weak::Set::StrongKeys}.
  # - JRuby < 9.4.6.0 has a similar `ObjectSpace::WeakMap` as newer JRuby
  #   versions with strong keys and weak values. However generally in JRuby,
  #   Integer values (including object_ids) can have multiple different object
  #   representations in memory and are not necessarily equal to each other when
  #   used as keys in an `ObjectSpace::WeakMap`. As a workaround we use an
  #   indirect implementation with a secondary lookup table for the keys in
  #   {Weak::Set::StrongSecondaryKeys}.
  #
  # The required strategy is selected automatically based in the running
  # Ruby. The external behavior is the same for all implementations.
  #
  # @example
  #   require "weak/set"
  #
  #   s1 = Weak::Set[1, 2]                  #=> #<Weak::Set {1, 2}>
  #   s2 = Weak::Set.new [1, 2]             #=> #<Weak::Set {1, 2}>
  #   s1 == s2                              #=> true
  #   s1.add(:foo)                          #=> #<Weak::Set {1, 2, :foo}>
  #   s1.merge([2, 6])                      #=> #<Weak::Set {1, 2, :foo, 6}>
  #   s1.subset?(s2)                        #=> false
  #   s2.subset?(s1)                        #=> true
  class Set
    include Enumerable

    # We try to find the best implementation strategy based on the current Ruby
    # engine and version. The chosen `STRATEGY` is included into the {Weak::Set}
    # class.
    STRATEGY = [
      Weak::Set::WeakKeysWithDelete,
      Weak::Set::WeakKeys,
      Weak::Set::StrongKeys,
      Weak::Set::StrongSecondaryKeys
    ].find(&:usable?)

    include STRATEGY

    ############################################################################
    # Here follows the documentation of strategy-specific methods which are
    # implemented in one of the include modules depending on the current Ruby.

    # @!macro weak_set_note_object_equality
    #   @note {Weak::Set} does not test member equality with `==` or `eql?`.
    #     Instead, it always checks strict object equality, so that, e.g.,
    #     different strings are not considered equal, even if they may contain
    #     the same string content.

    # @!macro weak_set_method_add
    #   Adds the given object to the weak set and return `self`. Use {#merge} to
    #   add many elements at once.
    #
    #   In contrast to other "regular" objects, we will not retain a strong
    #   reference to the added object. Unless some other live objects still
    #   references the object, it will eventually be garbage-collected.
    #
    #   @param obj [Object] an object
    #   @return [self]
    #
    #   @example
    #       Weak::Set[1, 2].add(3)                #=> #<Weak::Set {1, 2, 3}>
    #       Weak::Set[1, 2].add([3, 4])           #=> #<Weak::Set {1, 2, [3, 4]}>
    #       Weak::Set[1, 2].add(2)                #=> #<Weak::Set {1, 2}>

    # @!macro weak_set_method_clear
    #   Removes all elements and returns `self`
    #
    #   @return [self]

    # @!macro weak_set_method_delete_question
    #   Deletes the given object from `self` and returns `self` if it was
    #   present in the set. If the object was not in the set, returns `nil`.
    #
    #   @param obj [Object]
    #   @return [self, nil] `self` if the given object was deleted from the set
    #     or `nil` if the object was not part of the set
    #   @!macro weak_set_note_object_equality

    # @!macro weak_set_method_each
    #   Calls the given block once for each live element in `self`, passing that
    #   element as a parameter. Returns the weak set itself.
    #
    #   If no block is given, an `Enumerator` is returned instead.
    #
    #   @yield [element] calls the given block once for each element in `self`
    #   @yieldparam element [Object] the yielded value
    #   @return [self, Enumerator] `self` if a block was given or an
    #     `Enumerator` if no block was given.

    # @!macro weak_set_method_include_question
    #   @param obj [Object] an object
    #   @return [Bool] `true` if the given object is included in `self`, `false`
    #     otherwise
    #   @!macro weak_set_note_object_equality

    # @!macro weak_set_method_prune
    #   Cleanup data structures from the set to remove data associated with
    #   deleted or garbage collected elements. This method may be called
    #   automatically for some {Weak::Set} operations.
    #
    #   @return [self]

    # @!macro weak_set_method_replace
    #   Replaces the contents of `self` with the contents of the given
    #   enumerable object and returns `self`.
    #
    #   @param enum (see #do_with_enum)
    #   @return [self]
    #   @example
    #       set = Weak::Set[1, :c, :s]        #=> #<Weak::Set {1, :c, :s}>
    #       set.replace([1, 2])               #=> #<Weak::Set {1, 2}>
    #       set                               #=> #<Weak::Set {1, 2}>

    # @!macro weak_set_method_size
    #   @return [Integer] the number of live elements in `self`

    # @!macro weak_set_method_to_a
    #   @return [Array] the live elements contained in `self` as an `Array`
    #   @note The order of elements on the returned `Array` is
    #     non-deterministic. We do not preserve preserve insertion order.

    ############################################################################

    # @!method add(obj)
    #   @!macro weak_set_method_add

    # @!method clear
    #   @!macro weak_set_method_clear

    # @!method delete?(obj)
    #   @!macro weak_set_method_delete_question

    # @!method each
    #   @!macro weak_set_method_each

    # @!method include?(obj)
    #   @!macro weak_set_method_include_question

    # @!method prune
    #   @!macro weak_set_method_prune

    # @!method size
    #   @!macro weak_set_method_size

    # @!method replace(enum)
    #   @!macro weak_set_method_replace

    # @!method to_a
    #   @!macro weak_set_method_to_a

    ############################################################################

    # The same value as `Set::InspectKey`. This is used as a key in
    # `Thread.current` in {#inspect} to resolve object loops.
    INSPECT_KEY = :__inspect_key__
    private_constant :INSPECT_KEY

    # @param ary [Array<Object>] a list of objects
    # @return [Weak::Set] a new weak set containing the given objects
    #
    # @example
    #     Weak::Set[1, 2]                   # => #<Weak::Set {1, 2}>
    #     Weak::Set[1, 2, 1]                # => #<Weak::Set {1, 2}>
    #     Weak::Set[1, :c, :s]              # => #<Weak::Set {1, :c, :s}>
    def self.[](*ary)
      new(ary)
    end

    # @param enum (see #do_with_enum)
    # @yield [element] calls the given block once for each element in `enum` and
    #   add the block's return value instead if the enum's value. Make sure to
    #   only return objects which are references somewhere else to avoid them
    #   being quickly garbage collected again.
    # @yieldparam element [Object] the yielded value from the `enum`
    def initialize(enum = nil)
      clear

      return if enum.nil?
      if block_given?
        do_with_enum(enum) do |obj|
          add yield(obj)
        end
      else
        do_with_enum(enum) do |obj|
          add obj
        end
      end
    end

    alias_method :<<, :add
    alias_method :===, :include?
    alias_method :member?, :include?
    alias_method :length, :size
    alias_method :reset, :prune

    # @param enum (see #do_with_enum)
    # @return [Weak::Set] a new weak set built by merging `self` and the elements
    #   of the given enumerable object.
    # @!macro weak_set_note_object_equality
    #
    # @example
    #     Weak::Set[1, 2, 3] | Weak::Set[2, 4, 5] # => #<Weak::Set {1, 2, 3, 4, 5}>
    #     Weak::Set[1, 3, :z] | (1..4)            # => #<Weak::Set {1, 3, :z, 2, 4}>
    def |(enum)
      new_set = dup
      do_with_enum(enum) do |obj|
        new_set.add(obj)
      end
      new_set
    end
    alias_method :+, :|
    alias_method :union, :|

    # @param enum (see #do_with_enum)
    # @return [Weak::Set] a new weak set built by duplicating `self`, removing
    #   every element that appears in the given enumerable object from that.
    # @!macro weak_set_note_object_equality
    #
    # @example
    #     Weak::Set[1, 3, 5] - Weak::Set[1, 5]        # => #<Weak::Set {3}>
    #     Weak::Set['a', 'b', 'z'] - ['a', 'c']       # => #<Weak::Set {"b", "z"}>
    def -(enum)
      dup.subtract(enum)
    end
    alias_method :difference, :-

    # @param enum (see #do_with_enum g)
    # @return [Weak::Set] a new weak set containing elements common to `self`
    #   and the given enumerable object.
    # @!macro weak_set_note_object_equality
    #
    # @example
    #     Weak::Set[1, 3, 5] & Weak::Set[3, 2, 1]    # => #<Weak::Set {3, 1}>
    #     Weak::Set[1, 2, 9] & [2, 1, 3]             # => #<Weak::Set {1, 2}>
    def &(enum)
      new_set = self.class.new
      do_with_enum(enum) do |obj|
        new_set.add(obj) if include?(obj)
      end
      new_set
    end
    alias_method :intersection, :&

    # @param other [Weak::Set] a weak set
    # @return [Integer, nil] `0` if `self` and the given `set` contain the same
    #   elements, `-1` / `+1` if `self` is a proper subset / superset of the
    #   given `set`, or `nil` if they both have unique elements or `set` is not
    #   a {Weak::Set}
    # @!macro weak_set_note_object_equality
    def <=>(other)
      return unless Weak::Set === other
      return 0 if equal?(other)

      other_ary = other.to_a
      own_ary = to_a
      case own_ary.size <=> other_ary.size
      when -1
        -1 if own_ary.all?(other)
      when 1
        1 if other_ary.all?(self)
      else
        0 if own_ary.all?(other)
      end
    end

    # Returns true if two weak sets are equal. The equality of each couple
    # of elements is defined according to strict object equality so that, e.g.,
    # different strings are not equal, even if they may contain the same data.
    #
    # @param other [Weak::Set] a weak set to compare to `self`
    # @return [Bool] `true` if the `other` object is a weak set containing
    #   exactly the same elements as `self`, `false` otherwise
    #
    # @example
    #     Weak::Set[1, 2] == Weak::Set[2, 1]         #=> true
    #     Weak::Set[1, 3, 5] == Weak::Set[1, 5]      #=> false
    #     Weak::Set[1, 2, 3] == [1, 3, 2]            #=> false
    def ==(other)
      return true if equal?(other)
      return false unless Weak::Set === other

      other_ary = other.to_a
      own_ary = to_a

      return false unless own_ary.size == other_ary.size
      own_ary.all?(other)
    end

    # Returns a new weak set containing elements exclusive between `self` and
    # the given enumerable object. `(set ^ enum)` is equivalent to
    # `((set | enum) - (set & enum))`.
    #
    # @param enum (see #do_with_enum)
    # @return [Weak::Set] a new weak set
    # @!macro weak_set_note_object_equality
    #
    # @example
    #     Weak::Set[1, 2] ^ Set[2, 3]           #=> #<Weak::Set {3, 1}>
    #     Weak::Set[1, :b, :c] ^ [:b, :d]       #=> #<Weak::Set {:d, 1, :c}>
    def ^(enum)
      return dup if enum.nil?

      new_set = self.class.new.merge(enum)
      each do |obj|
        new_set.add(obj) unless new_set.delete?(obj)
      end
      new_set
    end

    # @param obj [Object] an object
    # @return [Object, nil] the provided `obj` if it is included in `self`,
    #   `nil` otherwise
    # @see #include?
    # @!macro weak_set_note_object_equality
    def [](obj)
      obj if include?(obj)
    end

    # Adds the given object to the weak set and returns `self`. If the object is
    # already in the set, returns `nil`.
    #
    # @param obj [Object] an object to add to the weak set
    # @return [self, nil] `self` if the object was added, `nil` if it was part
    #   of the set already
    # @!macro weak_set_note_object_equality
    #
    # @example
    #     Weak::Set[1, 2].add?(3)              #=> #<Weak::Set {1, 2, 3}>
    #     Weak::Set[1, 2].add?([3, 4])         #=> #<Weak::Set {1, 2, [3, 4]}>
    #     Weak::Set[1, 2].add?(2)              #=> nil
    def add?(obj)
      add(obj) unless include?(obj)
    end

    # {Weak::Set} objects can't be frozen since this is not enforced by the
    # underlying `ObjectSpace::WeakMap` implementation. Thus, we try to signal
    # this by not actually setting the `frozen?` flag and ignoring attempts to
    # freeze us with just a warning.
    #
    # @param freeze [Bool, nil] ignored; we always behave as if this is false.
    #   If this is set to a truethy value, we emit a warning.
    # @return [Weak::Set] a new `Weak::Set` object containing the same elements
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

    # Deletes the given object from `self` and returns `self`. Use {#subtract}
    # to delete many items at once.
    #
    # @param obj [Object] an object to delete from the weak set
    # @return [self] always returns self
    # @!macro weak_set_note_object_equality
    def delete(obj)
      delete?(obj)
      self
    end

    # Deletes every element of the weak set for which the given block block
    # evaluates to a truethy value, and returns `self`. Returns an `Enumerator`
    # if no block is given.
    #
    # @yield [element] calls the given block once with each element. If the
    #   block returns a truethy value, the element is deleted from the set
    # @yieldparam element [Object] a live element of the set
    # @return [self, Enumerator] `self` or an `Enumerator` if no block was given
    # @see #reject!
    def delete_if(&block)
      return enum_for(__method__) { size } unless block_given?

      each do |obj|
        delete?(obj) if yield(obj)
      end
      self
    end

    # @param enum (see #intersect)
    # @return [Bool] `true` if `self` and the given `enum` have no element in
    #   common. This method is the opposite of {#intersect?}.
    # @!macro weak_set_note_object_equality
    def disjoint?(enum)
      !intersect?(enum)
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

    # @return [String] a string containing a human-readable representation of
    #   the weak set, e.g., `"#<Weak::Set {element1, element2, ...}>"`
    def inspect
      object_ids = (Thread.current[INSPECT_KEY] ||= [])
      return "#<#{self.class} {...}>" if object_ids.include?(object_id)

      object_ids << object_id
      begin
        elements = to_a.sort_by!(&:__id__).inspect[1..-2]
        "#<#{self.class} {#{elements}}>"
      ensure
        object_ids.pop
      end
    end
    alias_method :to_s, :inspect

    # @param enum (see #enumerable)
    # @return [Bool] `true` if `self` and the given enumerable object have at
    #   least one element in common, `false` otherwise
    # @!macro weak_set_note_object_equality
    #
    # @example
    #     Weak::Set[1, 2, 3].intersect? Weak::Set[4, 5]   #=> false
    #     Weak::Set[1, 2, 3].intersect? Weak::Set[3, 4]   #=> true
    #     Weak::Set[1, 2, 3].intersect? 4..5              #=> false
    #     Weak::Set[1, 2, 3].intersect? [3, 4]            #=> true
    def intersect?(enum)
      case enum
      when Weak::Set
        enum_ary = enum.to_a
        own_ary = to_a

        if own_ary.size < enum_ary.size
          own_ary.any?(enum)
        else
          enum_ary.any?(self)
        end
      else
        enumerable(enum).any?(self)
      end
    end

    # Deletes every element from `self` for which the given block evaluates to
    # a falsey value.
    #
    # If no block is given, an `Enumerator` is returned instead.
    #
    # @yield [element] calls the given block once for each element in the
    #   array
    # @yieldparam element [Object] the element to check
    # @return [Enumerator, self] `self` if a block was given, or an
    #  `Enumerator` if no block was given.
    # @see select!
    def keep_if(&block)
      return enum_for(__method__) { size } unless block_given?

      each do |obj|
        delete?(obj) unless yield(obj)
      end
      self
    end

    # Merges the elements of the given enumerable objects to the set and returns
    # `self`
    #
    # @param enums [Array<#each_entry, #each>] a list of enumerable objects
    # @return [self]
    def merge(*enums, **nil)
      enums.each do |enum|
        do_with_enum(enum) do |obj|
          add(obj)
        end
      end
      self
    end

    # @!visibility private
    def pretty_print(pp)
      pp.group(1, "#<#{self.class}", ">") do
        pp.breakable
        pp.group(1, "{", "}") do
          pp.seplist(to_a.sort_by!(&:__id__)) do |obj|
            pp.pp obj
          end
        end
      end
    end

    # @!visibility private
    def pretty_print_cycle(pp)
      pp.text "#<#{self.class} {#{"..." unless empty?}}>"
    end

    # @param other [Weak::Set] a weak set
    # @return [Bool] `true` if `self` is a proper subset of the given `set`,
    #   `false` otherwise
    # @see subset?
    def proper_subset?(other)
      if Weak::Set === other
        other_ary = other.to_a
        own_ary = to_a

        return false unless own_ary.size < other_ary.size
        own_ary.all?(other)
      else
        raise ArgumentError, "value must be a weak set"
      end
    end
    alias_method :<, :proper_subset?

    # @param other [Weak::Set] a weak set
    # @return [Bool] `true` if `self` is a proper superset of the given `set`,
    #   `false` otherwise
    # @!macro weak_set_note_object_equality
    # @see superset?
    def proper_superset?(other)
      if Weak::Set === other
        other_ary = other.to_a
        own_ary = to_a

        return false unless own_ary.size > other_ary.size
        other_ary.all?(self)
      else
        raise ArgumentError, "value must be a weak set"
      end
    end
    alias_method :>, :proper_superset?

    # Deletes every live element from `self` for which the given block
    # evaluates to a truethy value.
    #
    # Equivalent to {#delete_if}, but returns `nil` if no changes were made.
    #
    # If no block is given, an `Enumerator` is returned instead.
    #
    # @yield [element] calls the given block once for each live object in `self`
    # @yieldparam element [Object] the element to check
    # @return [Enumerator, self, nil] `self` if a block was given and some
    #   element(s) were deleted, `nil` if a block was given but no keys were
    #   deleted, or an `Enumerator` if no block was given.
    # @see #delete_if
    def reject!(&block)
      return enum_for(__method__) { size } unless block_given?

      deleted_anything = false
      each do |obj|
        deleted_anything = true if yield(obj) && delete?(obj)
      end

      self if deleted_anything
    end

    # Deletes every element from `self` for which the given block evaluates to
    # a falsey value.
    #
    # Equivalent to {#keep_if}, but returns `nil` if no changes were made.
    #
    # If no block is given, an `Enumerator` is returned instead.
    #
    # @yield [element] calls the given block once for each element in the set
    # @yieldparam element [Object] the element to check
    # @return [Enumerator, self, nil] `self` if a block was given and some
    #   element(s) were deleted, `nil` if a block was given but nothing was
    #   deleted, or an `Enumerator` if no block was given.
    # @see keep_if
    def select!(&block)
      return enum_for(__method__) { size } unless block_given?

      deleted_anything = false
      each do |obj|
        deleted_anything = true if !yield(obj) && delete?(obj)
      end

      self if deleted_anything
    end
    alias_method :filter!, :select!

    # @param other [Weak::Set] a weak set
    # @return [Bool] `true` if `self` is a subset of the given `set`, `false`
    #   otherwise
    # @!macro weak_set_note_object_equality
    # @see proper_subset?
    def subset?(other)
      if Weak::Set === other
        other_ary = other.to_a
        own_ary = to_a

        return false unless own_ary.size <= other_ary.size
        own_ary.all?(other)
      else
        raise ArgumentError, "value must be a weak set"
      end
    end
    alias_method :<=, :subset?

    # Deletes every element from `self` which appears in the given enumerable
    # object `enum` and returns `self`.
    #
    # @param enum (see #do_with_enum)
    # @return [self]
    def subtract(enum)
      do_with_enum(enum) do |obj|
        delete?(obj)
      end
      self
    end

    # @param other [Weak::Set] a weak set
    # @return [Bool] `true` if `self` is a superset of the given `set`, `false`
    #   otherwise
    # @see proper_superset?
    def superset?(other)
      if Weak::Set === other
        other_ary = other.to_a
        own_ary = to_a

        return false unless own_ary.size >= other_ary.size
        other_ary.all?(self)
      else
        raise ArgumentError, "value must be a weak set"
      end
    end
    alias_method :>=, :superset?

    # @return [Set] the elements in `self` as a regular `Set` with strong object
    #   references
    # @note The returned set is configured to compare elements by their object
    #   identity, similar to a `Weak::Set`.
    def to_set
      set = ::Set.new.compare_by_identity
      each do |obj|
        set.add(obj)
      end
      set
    end

    private

    # @param enum [Weak::Set, #each_entry #each] a {Weak::Set} or an enumerable
    #   object
    # return [void]
    # @raise [ArgumentError] if the given `enum` is not enumerable
    def do_with_enum(enum, &block)
      if Weak::Set === enum
        enum.each(&block)
      elsif enum.respond_to?(:each_entry)
        enum.each_entry(&block)
      elsif enum.respond_to?(:each)
        enum.each(&block)
      else
        raise ArgumentError, "value must be enumerable"
      end
    end

    # @param enum [Weak::Set, Enumerable, #each_entry, #each] a {Weak::Set}, or
    #   an Enumerable object, e.g. an `Array` or `Set`, or an object which
    #   responds to `each_entry` or `each`
    # @return [Enumerable] an object which is an `Enumerable`
    def enumerable(enum)
      if Enumerable === enum
        enum
      elsif enum.respond_to?(:each_entry)
        enum.enum_for(:each_entry)
      elsif enum.respond_to?(:each)
        enum.enum_for(:each)
      else
        raise ArgumentError, "value must be enumerable"
      end
    end

    # Callback method which is called on the new object during `dup` or `clone`
    def initialize_copy(orig)
      initialize(orig)
    end
  end
end
