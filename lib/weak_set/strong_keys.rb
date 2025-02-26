# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

##
class WeakSet
  # This WeakSet strategy targets JRuby >= 9.4.6.0 and TruffleRuby >= 22.
  # Older versions require additional indirections implemented in
  # {WeakSet::StrongSecondaryKeys}:
  #
  # - https://github.com/jruby/jruby/issues/7862
  # - https://github.com/oracle/truffleruby/issues/2267
  #
  # The ObjectSpace::WeakMap on JRuby and TruffleRuby has strong keys and weak
  # values. Thus, only the value object can be garbage collected to remove the
  # entry while the key defines a strong object reference which prevents the key
  # object from being garbage collected.
  #
  # As a workaround, we use the element's object_id as a key. Being an Integer,
  # the object_id is generally is not garbage collected anyway but allows to
  # uniquely identity the object.
  #
  # The WeakMaps do not allow to explicitly delete entries. We emulate this by
  # setting the garbage-collectible value of a deleted entry to a simple new
  # object. This value will be garbage collected on the next GC run which will
  # then remove the entry. When accessing elements, we delete and filter out
  # these recently deleted entries.
  module StrongKeys
    class DeletedEntry; end
    private_constant :DeletedEntry

    # Checks if this strategy is usable for the current Ruby version.
    #
    # @return [Bool] truethy for Ruby, TruffleRuby and modern JRuby, falsey
    #   otherwise
    def self.usable?
      case RUBY_ENGINE
      when "ruby", "truffleruby"
        true
      when "jruby"
        Gem::Version.new(RUBY_ENGINE_VERSION) >= Gem::Version.new("9.4.6.0")
      end
    end

    # @!macro weak_set_method_add
    def add(obj)
      @map[obj.__id__] = obj
      self
    end

    # @!macro weak_set_method_clear
    def clear
      @map = ObjectSpace::WeakMap.new
      self
    end

    # @!macro weak_set_method_delete_question
    def delete?(obj)
      key = obj.__id__
      return unless @map.key?(key) && @map[key].equal?(obj)

      # If there is a valid value in the WeakMap (with a strong object_id
      # key), we replace the value of the strong key with a temporary
      # DeletedEntry object. As we do not keep any strong reference to this
      # object, this will cause the key/value entry to vanish from the WeakMap
      # when the DeletedEntry object is eventually garbage collected.
      @map[key] = DeletedEntry.new
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
      key = obj.__id__
      !!(@map.key?(key) && @map[key].equal?(obj))
    end

    # @!macro weak_set_method_size
    def size
      # Compared to using WeakMap#each_value like we do in WeakKeys, this
      # version is
      #   * ~12% faster on JRuby >= 9.4.6.0
      #   * sam-ish on TruffleRuby 24 with a slight advantage to this version
      @map.values.delete_if { |obj| DeletedEntry === obj }.size
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
