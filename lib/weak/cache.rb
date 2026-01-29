# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require_relative "map"

##
module Weak
  # `Weak::Cache` provides a thread-safe wrapper around {Weak::Map} to provide
  # an object cache. As with a {Weak::Map}, keys and values are both weakly
  # referenced so that a stored key-value pair vanishes if either the key or
  # the value is garbage-collected.
  #
  # We implement an interface similar to that of `ActiveSupport::Cache::Store`.
  class Cache
    # Returns a new empty {Weak::Cache} object
    def initialize
      @map = Map.new
      @mutex = Mutex.new
    end

    # Clears the entire cache.
    #
    # @return [self]
    def clear
      @mutex.synchronize { @map.clear }
      self
    end

    # {Weak::Cache} objects can't be frozen since this is not enforced by the
    # underlying {Weak::Map}, resp. its `ObjectSpace::WeakMap` implementation.
    # Thus, we try to signal this by not actually setting the `frozen?` flag and
    # ignoring attempts to freeze us with just a warning.
    #
    # @param freeze [Bool, nil] ignored; we always behave as if this is false.
    #   If this is set to a truethy value, we emit a warning.
    # @return [Weak::Cache] a new `Weak::Cache` object containing the same elements
    #   as `self`
    def clone(freeze: false)
      warn("Can't freeze #{self.class}") if freeze
      @mutex.synchronize { super(freeze: false) }
    end

    # Deletes an entry in the cache. Returns `true` if an entry was deleted,
    # `false` otherwise.
    #
    # @param key [Object] the key to delete
    # @return [Bool] `true` if the entry was deleted, `false` otherwise
    # @!macro weak_map_note_object_equality
    def delete(key)
      @mutex.synchronize {
        @map.delete(key) do
          return false
        end
        true
      }
    end

    # @return [Weak::Cache] a new `Weak::Cache` object containing the same elements
    #   as `self`
    def dup
      @mutex.synchronize { super }
    end

    def each_key(&block)
      return enum_for(__method__) { size } unless block_given?
      keys.each(&block)
      self
    end

    # (see Weak::Map#empty?)
    def empty?
      @mutex.synchronize { @map.empty? }
    end

    # (see Weak::Map#include?)
    def exist?(key)
      @mutex.synchronize { @map.include?(key) }
    end
    alias_method :include?, :exist?
    alias_method :key?, :exist?

    # Fetches or sets data from the cache, using the given `key`. If there is a
    # value in the cache for the given key, that value is returned.
    #
    # If there is no value in the cache (a cache miss), then the given block
    # will be passed the key and executed in the event of a cache miss. The
    # return value of the block will be written to the cache under the given
    # cache key, and that return value will be returned.
    #
    # @param key [Object] the key for the requested value
    # @param skip_nil [Bool] prevents caching a `nil` value from the block
    # @yield [key] if no value was set at `key`, we call the block, write its
    #   returned value for the `key` in the cache and return the value
    # @yieldparam key [String] the given `key`
    # @return [Object] the value for the given `key` if present in the cache. If
    #   the key was not found, we return the value of the given block.
    # @raise [ArgumentError] if no block was provided
    # @!macro weak_map_note_object_equality
    def fetch(key, skip_nil: false)
      raise ArgumentError, "must provide a block" unless block_given?

      @mutex.synchronize {
        @map.fetch(key) {
          value = yield(key)
          @map[key] = value unless skip_nil && value.nil?
        }
      }
    end

    # {Weak::Cache} objects can't be frozen since this is not enforced by the
    # underlying {Weak::Map}, resp. its `ObjectSpace::WeakMap` implementation.
    # Thus, we try to signal this by not actually setting the `frozen?` flag and
    # ignoring attempts to freeze us with just a warning.
    #
    # @return [self]
    def freeze
      warn("Can't freeze #{self.class}")
      self
    end

    def inspect
      @mutex.synchronize { "#<#{self.class} #{@map._inspect}>" }
    end

    # (see Weak::Map#keys)
    def keys
      @mutex.synchronize { @map.keys }
    end

    # @!visibility private
    def pretty_print(pp)
      pp.group(1, "#<#{self.class}", ">") do
        pp.breakable
        pp.pp @mutex.synchronize {
          @map.to_a.sort_by! { |k, _v| k.__id__ }.to_h
        }
      end
    end

    # @!visibility private
    def pretty_print_cycle(pp)
      pp.text "#<#{self.class} {#{"..." unless empty?}}>"
    end

    # @param key [Object] the key for the requested value
    # @return [Object] the value associated with the given `key`, or `nil` if
    #   no value was found for the `key`
    # @!macro weak_map_note_object_equality
    def read(key)
      @mutex.synchronize { @map[key] }
    end
    alias_method :[], :read

    def size
      @mutex.synchronize { @map.size }
    end
    alias_method :length, :size

    # (see Weak::Map#to_h)
    def to_h(&block)
      @mutex.synchronize { @map.to_h(&block) }
    end

    # (see Weak::Map#[]=)
    def write(key, value)
      @mutex.synchronize { @map[key] = value }
    end
    alias_method :[]=, :write

    private

    def initialize_copy(orig)
      @map = @map.dup
      @mutex = Mutex.new
    end
  end
end
