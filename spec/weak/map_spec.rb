# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require "spec_helper"

require "pp"

RSpec.describe Weak::Map do
  let(:map) { Weak::Map.new }

  def strategy?(*strategies)
    strategies = strategies.map { |strategy| "Weak::Map::#{strategy}" }

    Weak::Map.ancestors.any? { |mod| strategies.include?(mod.name) }
  end

  def expect_prune_on
    return unless strategy?("StrongKeys", "StrongSecondaryKeys")

    map = Weak::Map.new
    map[:key] = :value

    collectable do
      keys = (1..4999).to_a
      values = []

      keys.each do |key|
        values << (value = key.to_s)
        map[key] = value
      end

      expect(map.instance_variable_get(:@keys).size).to eq 5000
      expect(map.instance_variable_get(:@values).size).to eq 5000
      if strategy?("StrongSecondaryKeys")
        expect(map.instance_variable_get(:@key_map).size).to eq 5000
      end
    end

    garbage_collect_until do
      expect(map.instance_variable_get(:@values).size).to eq 1
    end
    if strategy?("StrongSecondaryKeys")
      expect(map.instance_variable_get(:@key_map).size).to eq 5000
    end

    expect(map).to receive(:auto_prune).and_call_original
    expect(map).to receive(:prune).and_call_original

    yield(map)

    garbage_collect_until do
      expect(map.instance_variable_get(:@keys).size).to eq 1
      expect(map.instance_variable_get(:@values).size).to eq 1
    end
    if strategy?("StrongSecondaryKeys")
      expect(map.instance_variable_get(:@key_map).size).to eq 1
    end
  end

  context "with strategies" do
    it "implement the same methods" do
      [
        Weak::Map::WeakKeysWithDelete,
        Weak::Map::WeakKeys,
        Weak::Map::StrongKeys,
        Weak::Map::StrongSecondaryKeys
      ].each_cons(2) do |s1, s2|
        expect(s1.instance_methods.sort).to match s2.instance_methods.sort
      end
    end
  end

  it "is an Enumerable" do
    expect(Weak::Map).to be < ::Enumerable
    expect(::Enumerable.public_instance_methods - map.methods)
      .to be_empty
  end

  describe ".[]]" do
    it "returns a new map" do
      expect(Weak::Map[]).to be_instance_of(Weak::Map).and be_empty
      expect(Weak::Map[{}]).to be_instance_of(Weak::Map).and be_empty
    end

    it "converts a Hash" do
      hash = {a: 1, b: 2}
      expect(Weak::Map[hash])
        .to be_instance_of(Weak::Map)
        .and have_attributes(
          to_h: {a: 1, b: 2}.compare_by_identity
        )
    end

    it "returns a copy of Weak::Map" do
      map = Weak::Map.new
      map[:a] = 1

      expect(Weak::Map[map])
        .to be_instance_of(Weak::Map)
        .and not_equal(map)
        .and have_attributes(
          to_h: {a: 1}.compare_by_identity
        )
    end

    it "raises a TypeError for unexpeced values" do
      expect { Weak::Map[[[:a, 1]]] }.to raise_error(NoMethodError)
      expect { Weak::Map[:map] }.to raise_error(NoMethodError)
      expect { Weak::Map[nil] }.to raise_error(NoMethodError)
    end
  end

  describe "#initialize" do
    it "returns a Weak::Map" do
      expect(Weak::Map.new).to be_instance_of Weak::Map
    end

    it "accepts a default value" do
      default = +"foo"
      expect(Weak::Map.new(default).default).to equal default
      expect(Weak::Map.new(default)[:missing]).to equal default
    end

    it "accepts a default block" do
      expect(Weak::Map.new { |map, key| key + 1 }.default_proc).to be_a Proc
      expect(Weak::Map.new { |map, key| key + 1 }.default).to be_nil
      expect(Weak::Map.new { |map, key| key + 1 }[42]).to eq 43
    end

    it "raises an AgumentError if both a proc and a value are given" do
      expect { Weak::Map.new(23) { 42 } }.to raise_error(ArgumentError)
    end
  end

  describe "#[]" do
    it "returns the value for a key" do
      obj = instance_double(String)
      foo = +"foo"
      bar = +"bar"
      baz = +"baz"
      map[1] = 2
      map[3] = 4
      map[foo] = bar
      map[obj] = obj
      map[bar] = nil
      map[nil] = 5
      map[false] = 6
      map[:sym] = baz

      expect(map[1]).to eq 2
      expect(map[3]).to eq 4
      expect(map[foo]).to equal bar
      expect(map[obj]).to equal obj
      expect(map[bar]).to be_nil
      expect(map[nil]).to eq 5
      expect(map[false]).to eq 6
      expect(map[:sym]).to equal baz
    end

    it "returns nil as default value" do
      map[0] = 0
      expect(map[5]).to be_nil
      expect(map[nil]).to be_nil
    end

    it "returns the default (immediate) value for missing keys" do
      map = Weak::Map.new(5)
      expect(map[:a]).to eq 5

      map[:a] = 0
      expect(map[:a]).to eq 0
      expect(map[:b]).to eq 5
    end

    it "does not create copies of the immediate default value" do
      str = +"foo"
      map = Weak::Map.new(str)
      a = map[:a]
      b = map[:b]
      a << "bar"

      expect(a).to equal(b)
      expect(a).to eq "foobar"
      expect(b).to eq "foobar"
    end

    it "returns the default (dynamic) value for missing keys" do
      map = Weak::Map.new { |map, k| map[k] = k.is_a?(Numeric) ? k + 2 : k }

      expect(map[1]).to eq 3
      expect(map[:this]).to eq :this
      expect(map.to_h).to eq({1 => 3, :this => :this}.compare_by_identity)

      i = 0
      map = Weak::Map.new { |map, key| i += 1 }
      expect(map[:foo]).to eq 1
      expect(map[:foo]).to eq 2
      expect(map[:bar]).to eq 3
    end

    it "does not return default values for nil value" do
      map = Weak::Map.new(5)
      map[:a] = nil
      expect(map[:a]).to be_nil

      map = Weak::Map.new { 5 }
      map[:a] = nil
      expect(map[:a]).to be_nil
    end

    it "compares keys by object identity" do
      foo = +"foo"
      bar = +"bar"

      map[foo] = bar
      expect(map[foo]).to equal bar
      expect(map["foo"]).to be_nil

      map[[]] = foo
      expect(map[[]]).to be_nil

      map[1.0] = foo
      expect(map[1]).to be_nil

      map[2] = foo
      expect(map[2.0]).to be_nil
    end

    it "skips deleted entries" do
      foo = +"foo"

      map[foo] = 2
      expect(map[foo]).to eq 2

      map.delete(foo)
      expect(map[foo]).to be_nil
    end

    it "skips garbage-collected values" do
      collectable do
        value = Object.new
        map[123] = value
        expect(map[123]).to eq value
      end

      garbage_collect_until do
        expect(map[123]).to be_nil
      end
    end

    it "skips garbage-collected keys" do
      next unless strategy?("StrongKeys", "StrongSecondaryKeys")

      key_id = nil

      collectable do
        key1 = Object.new
        key_id = key1.__id__

        map[key1] = 5
        expect(map[key1]).to eq 5
      end

      garbage_collect_until do
        expect(map).to be_empty
      end

      key2 = Object.new
      key2.define_singleton_method(:__id__) { key_id }
      expect(map[key2]).to be_nil
    end

    it "auto prunes with missing key" do
      expect_prune_on do |map|
        expect(map[:missing]).to be_nil
      end
    end

    it "auto prunes with an existing key" do
      expect_prune_on do |map|
        expect(map[:key]).to eq :value
      end
    end
  end

  describe "#[]=" do
    it "associates the key with the value and return the value" do
      map[:a] = 1
      expect(map[:b] = 2).to eq 2
      expect(map.send(:[]=, :c, 3)).to eq 3

      expect(map.to_h).to eq({a: 1, b: 2, c: 3}.compare_by_identity)
    end

    it "does not duplicate string keys" do
      key = +"foo"
      expect(key).not_to receive(:dup)

      map[key] = 0
      expect(map.keys[0]).to equal key
    end

    it "does not freeze keys" do
      key = +"foo"
      expect(key).not_to receive(:freeze)

      map[key] = 0
      expect(map.keys[0]).to equal(key).and not_be_frozen
    end

    it "stores keys by their object identity" do
      k1 = [+"x"]
      k2 = [+"x"]

      expect(k1).to eql k2
      expect(k1).not_to equal k2

      expect(k1).not_to receive(:hash)
      map[k1] = 1

      expect(k2).not_to receive(:hash)
      map[k2] = 2

      expect(map.size).to eq 2
    end

    it "does not raise an exception if changing the value of an existing key during iteration" do
      map[1] = 2
      map[3] = 4
      map[5] = 6

      map.each { map[1] = :foo }
      expect(map.to_h).to eq({1 => :foo, 3 => 4, 5 => 6}.compare_by_identity)
    end
  end

  describe "#clear" do
    it "clears the map" do
      map[:a] = 1
      expect(map.clear).to equal(map).and be_empty
    end

    it "cleans up internal data" do
      map[:a] = 1
      if strategy?("WeakKeys")
        expect(map.instance_variable_get(:@map).size).to eq 1
        map.clear
        expect(map.instance_variable_get(:@map).size).to eq 0
      elsif strategy?("StrongKeys")
        expect(map.instance_variable_get(:@keys).size).to eq 1
        expect(map.instance_variable_get(:@values).size).to eq 1
        map.clear
        expect(map.instance_variable_get(:@keys).size).to eq 0
        expect(map.instance_variable_get(:@values).size).to eq 0
      elsif strategy?("StrongSecondaryKeys")
        expect(map.instance_variable_get(:@key_map).size).to eq 1
        expect(map.instance_variable_get(:@keys).size).to eq 1
        expect(map.instance_variable_get(:@values).size).to eq 1
        map.clear
        expect(map.instance_variable_get(:@key_map).size).to eq 0
        expect(map.instance_variable_get(:@keys).size).to eq 0
        expect(map.instance_variable_get(:@values).size).to eq 0
      end
    end

    it "retains the default value" do
      map.default = :default
      map[:a] = 1

      map.clear
      expect(map).to be_empty
      expect(map.default).to eq :default
    end

    it "retains the default proc" do
      map.default_proc = ->(_map, key) { key.to_s.upcase }
      map[:a] = 1

      map.clear
      expect(map).to be_empty
      expect(map.default_proc).not_to be_nil
      expect(map.default(:key)).to eq "KEY"
    end
  end

  describe "#clone" do
    it "clones the map" do
      map[:foo] = 1

      expect(map.clone)
        .to be_a(Weak::Map)
        .and not_equal(map)
        .and have_attributes(to_h: {foo: 1}.compare_by_identity)

      clone = map.clone
      map[:bar] = 2
      clone[:boing] = 3

      expect(map.to_h).to eq({foo: 1, bar: 2}.compare_by_identity)
      expect(clone.to_h).to eq({foo: 1, boing: 3}.compare_by_identity)
    end

    it "allows to use freeze: false" do
      map[:foo] = 1

      expect(map.clone(freeze: false))
        .to be_a(Weak::Map)
        .and not_be_frozen
        .and not_equal(map)
        .and have_attributes(to_h: {foo: 1}.compare_by_identity)
    end

    it "ignores freeze: true" do
      allow(map).to receive(:warn)

      map[:foo] = 1
      expect(map.clone(freeze: true))
        .to be_a(Weak::Map)
        .and not_be_frozen
        .and not_equal(map)
        .and have_attributes(to_h: {foo: 1}.compare_by_identity)

      expect(map).to have_received(:warn).with("Can't freeze Weak::Map")

      # Instance variables of the cloned map won't be frozen either
      expect(map.clone(freeze: true).instance_variables).to all satisfy { |var|
        value = map.instance_variable_get(var)
        value.nil? || !value.frozen?
      }
    end

    it "sets the default value" do
      allow(map).to receive(:warn)

      default = +"a value"
      map.default = default

      expect(map.clone.default).to equal default
      expect(map.clone(freeze: false).default).to equal default
      expect(map.clone(freeze: false).default).to equal default
    end

    it "sets the default proc" do
      allow(map).to receive(:warn)

      default_proc = ->(map, key) { key }
      map.default_proc = default_proc

      expect(map.clone.default_proc).to equal default_proc
      expect(map.clone(freeze: false).default_proc).to equal default_proc
      expect(map.clone(freeze: true).default_proc).to equal default_proc
    end
  end

  describe "#compare_by_identity" do
    it "returns self" do
      expect(map.compare_by_identity).to equal map
    end
  end

  describe "#compare_by_identity?" do
    it "always returns true" do
      expect(map.compare_by_identity?).to be true
      map.compare_by_identity
      expect(map.compare_by_identity?).to be true
    end
  end

  describe "#default" do
    it "returns nil by default" do
      expect(map.default).to be_nil
    end

    context "with a default value" do
      let(:default) { +"foo" }
      let(:map) { Weak::Map.new(default) }

      it "returns the defaut value" do
        expect(map.default).to equal default
      end

      it "returns the default value for a missing key" do
        expect(map.default(:missing)).to equal default
      end

      it "returns the default value for an existing key" do
        map[:key] = :value
        expect(map.default(:key)).to equal default
      end
    end

    context "with a default proc" do
      let(:map) { Weak::Map.new { |map, key| key.to_s.upcase } }

      it "returns nil" do
        expect(map.default).to be_nil
      end

      it "calls the default proc for a missing key" do
        expect(map.default(:missing)).to eq "MISSING"
      end

      it "calls the default proc for an existing key" do
        map[:key] = :value
        expect(map.default(:key)).to eq "KEY"
      end
    end
  end

  describe "#default=" do
    it "sets the default value" do
      expect(map.default = :foo).to eq :foo
      expect(map.default).to eq :foo
    end

    it "clears the default_proc" do
      map.default_proc = ->(map, key) { key }
      expect(map.default_proc).to be_a Proc

      map.default = false
      expect(map.default).to be false
      expect(map.default_proc).to be_nil
    end
  end

  describe "#default_proc" do
    it "returns nil without a proc" do
      expect(map.default_proc).to be_nil
    end

    it "returns the proc" do
      default = proc { |map, key| key.to_s.upcase }
      expect(Weak::Map.new(&default).default_proc).to eq default

      expect(Weak::Map.new(&default).default_proc.call(nil, :foo)).to eq "FOO"
    end
  end

  describe "#default_proc=" do
    it "can set a proc" do
      default = proc { |map, key| key.to_s.upcase }

      expect(map.default_proc = default).to equal default
      expect(map.default_proc).to equal default
    end

    it "accepts an object which responds to to_proc" do
      obj = instance_double(Symbol, to_proc: proc { "Montreal" })
      expect(map.default_proc = obj).to equal obj
      expect(map.default_proc).to be_a Proc
      expect(map[:city]).to eq "Montreal"
    end

    it "clears the default value" do
      map.default = false
      expect(map.default).to be false

      map.default_proc = ->(map, key) { key }
      expect(map.default_proc).to be_a Proc
      expect(map.default).to be_nil
      expect(map.default(:foo)).to eq :foo
    end

    it "clears the default proc if passed nil" do
      map = Weak::Map.new { "Paris" }
      expect(map.default_proc = nil).to be_nil
      expect(map.default_proc).to be_nil
      expect(map[:city]).to be_nil
    end

    it "raises TypeError if the argument does not respond to to_proc" do
      expect { map.default_proc = 123 }.to raise_error TypeError
    end

    it "raises TypeError if the argument's to_proc does not return a proc" do
      bogus = instance_double(Proc, to_proc: :invalid)
      expect { map.default_proc = bogus }.to raise_error TypeError
    end

    it "accepts a proc with any arity" do
      expect { map.default_proc = proc { |a| } }.not_to raise_error
      expect { map.default_proc = proc { |a, b, c| } }.not_to raise_error
      expect { map.default_proc = proc { |a, b, c:| } }.not_to raise_error
      expect { map.default_proc = proc { |a, b, c, *d| } }.not_to raise_error
    end

    it "raises a TypeError if passed a lambda with an arity other than 2" do
      expect { map.default_proc = ->(a) {} }.to raise_error(TypeError)
      expect { map.default_proc = ->(a, b, c) {} }.to raise_error(TypeError)
      expect { map.default_proc = ->(a, b, c:) {} }.to raise_error(TypeError)
      expect { map.default_proc = ->(a, b, c, *d) {} }.to raise_error(TypeError)
    end

    it "accepts a lambda with an arity of ~2" do
      expect { map.default_proc = ->(a, b) {} }.not_to raise_error
      expect { map.default_proc = ->(a, b, c = nil) {} }.not_to raise_error
      expect { map.default_proc = ->(a, *b) {} }.not_to raise_error
      expect { map.default_proc = ->(*a) {} }.not_to raise_error
    end

    it "raises exceptions during to_proc" do
      bogus = instance_double(Proc)
      allow(bogus).to receive(:to_proc).and_raise(RuntimeError, "aaaahhh")

      expect { map.default_proc = bogus }.to raise_error RuntimeError, "aaaahhh"
    end

    it "replaces the block passed to Map.new" do
      map = Weak::Map.new { "Paris" }
      map.default_proc = proc { "Montreal" }

      expect(map.default_proc.call(1)).to eq "Montreal"
      expect(map[1]).to eq "Montreal"
    end
  end

  describe "#delete" do
    it "removes the entry and returns the deleted value" do
      map[:a] = 5
      map[:b] = 2

      expect(map.delete(:b)).to eq 2
      expect(map.to_h).to match(a: 5)
    end

    it "calls supplied block if the key is not found" do
      map[:a] = 1
      expect(map.delete(:b) { 5 }).to eq 5

      expect(Weak::Map.new(:default).delete(:b) { 5 }).to eq 5
      expect(Weak::Map.new { :default }.delete(:b) { 5 }).to eq 5
    end

    it "returns nil if the key is not found when no block is given" do
      map[:a] = 1

      expect(map.delete(:b)).to be_nil
      expect(Weak::Map.new(:default).delete(:b)).to be_nil
      expect(Weak::Map.new { :default }.delete(:b)).to be_nil
    end

    it "allows removing a key while iterating" do
      (:a..:z).each_with_index do |char, i|
        map[char] = i + 1
      end

      visited = []
      map.each_pair do |key, value|
        visited << key
        map.delete(key)
      end

      expect(visited).to match_array((:a..:z))
      expect(map).to be_empty
    end

    it "checks keys by object identity" do
      k1 = +"foo"
      k2 = +"foo"
      expect(k1).not_to equal k2

      map[k1] = :k1
      map[k2] = :k2
      expect(map.size).to eq 2

      expect(map.delete(k1)).to eq :k1
      expect(map.size).to eq 1

      expect(map.delete(k1)).to be_nil
      expect(map.size).to eq 1

      expect(map.delete(k2)).to eq :k2
      expect(map).to be_empty
    end
  end

  describe "#delete_if" do
    before do
      map.merge!({a: 1, b: 3, c: 1, d: 2, e: 5})
    end

    it "yields two arguments: key and value" do
      all_args = []
      map.delete_if { |*args| all_args << args }
      expect(all_args.sort).to eq [[:a, 1], [:b, 3], [:c, 1], [:d, 2], [:e, 5]]
    end

    it "keeps every entry for which block is true and returns self" do
      expect(map.delete_if { |k, v| v > 4 })
        .to equal(map)
        .and have_attributes(
          to_h: {a: 1, b: 3, c: 1, d: 2}.compare_by_identity
        )
    end

    it "removes all entries if the block is true" do
      expect(map.delete_if { |_k, _v| true })
        .to equal(map)
        .and be_empty
    end

    it "returns self even if unmodified" do
      expect(map.delete_if { false }).to equal(map)
    end

    it "returns an Enumerator if called on a non-empty map without a block" do
      expect(map.delete_if)
        .to be_an_instance_of(Enumerator)
        .and have_attributes(size: 5)
    end

    it "returns an Enumerator if called on an empty map without a block" do
      expect(Weak::Map.new.delete_if)
        .to be_an_instance_of(Enumerator)
        .and have_attributes(size: 0)
    end
  end

  describe "#dup" do
    it "duplicates the map" do
      map[:a] = 1
      expect(map.dup)
        .to be_a(Weak::Map)
        .and not_equal(map)
        .and have_attributes(to_h: {a: 1}.compare_by_identity)

      dup = map.dup
      map[:foo] = 23
      dup[:bar] = 42

      expect(map.to_h).to eq({a: 1, foo: 23}.compare_by_identity)
      expect(dup.to_h).to eq({a: 1, bar: 42}.compare_by_identity)
    end

    it "sets the default value" do
      default = +"a value"
      map.default = default

      expect(map.dup.default).to equal default
    end

    it "sets the default proc" do
      default_proc = ->(map, key) { key }
      map.default_proc = default_proc

      expect(map.dup.default_proc).to equal default_proc
    end
  end

  describe "#each_key" do
    before do
      map[:a] = 1
      map[:b] = 2
    end

    it "calls block once for each key" do
      map[:c] = nil
      map[nil] = 2

      yielded = []
      expect(map.each_key { |*args| yielded << args }).to equal map
      expect(yielded).to contain_exactly([:a], [:b], [:c], [nil])
    end

    it "skips deleted entries" do
      yielded = []
      map.each_key { |*args| yielded << args }
      expect(yielded).to contain_exactly([:a], [:b])

      map.delete(:a)
      expect { |b| map.each_key(&b) }.to yield_with_args(:b)
    end

    it "skips garbage-collected keys" do
      map.clear

      collectable do
        key = +"foo"
        map[key] = 123
        expect { |b| map.each_key(&b) }.to yield_with_args(key)
      end

      garbage_collect_until do
        expect { |b| map.each_key(&b) }.not_to yield_control
      end
    end

    it "skips garbage-collected values" do
      map.clear

      collectable do
        value = +"foo"
        map[123] = value
        expect { |b| map.each_key(&b) }.to yield_with_args(123)
      end

      garbage_collect_until do
        expect { |b| map.each_key(&b) }.not_to yield_control
      end
    end

    it "returns an Enumerator if called on a non-empty hash without a block" do
      expect(map.each_value)
        .to be_instance_of(Enumerator)
        .and have_attributes(size: 2)
    end

    it "returns an Enumerator if called on an empty hash without a block" do
      expect(Weak::Map.new.each_value)
        .to be_instance_of(Enumerator)
        .and have_attributes(size: 0)
    end
  end

  describe "#each_pair" do
    before do
      map[:a] = 1
      map[:b] = 2
    end

    it "yields the key and value to a block expecting |key, value|" do
      args = []
      map.each_pair { |key, value| args << [key, value] }
      expect(args.sort).to eq [[:a, 1], [:b, 2]]
    end

    it "yields a [[key, value]] Array to a block expecting |*args|" do
      all_args = []
      map.each_pair { |*args| all_args << args }
      expect(all_args.sort).to eq [[[:a, 1]], [[:b, 2]]]
    end

    it "yields the key only to a block expecting |key,|" do
      args = []
      map.each_pair { |k,| args << k }
      expect(args.sort).to eq [:a, :b]
    end

    it "always yields an Array of 2 elements, even when given a callable of arity 2" do
      obj = Object.new
      def obj.foo(key, value)
        nil
      end

      expect { map.each_pair(&obj.method(:foo)) }.to raise_error(ArgumentError)

      # JRuby does not raise when yielding a two-element Array to a lambda which
      # expects two arguments. They handle this correctly for Hash#each but not
      # a generic yield. Both Ruby and TruffleRuby raise here.
      # https://github.com/jruby/jruby/issues/8694
      unless RUBY_ENGINE == "jruby"
        expect { map.each_pair(&->(k, v) {}) }.to raise_error(ArgumentError)
      end
    end

    it "returns self" do
      expect(map.each_pair { |k, v| [k, v] }).to equal(map)
    end

    it "returns an Enumerator if called on a non-empty hash without a block" do
      expect(map.each_pair)
        .to be_instance_of(Enumerator)
        .and have_attributes(size: 2)
    end

    it "returns an Enumerator if called on an empty hash without a block" do
      expect(Weak::Map.new.each_pair)
        .to be_instance_of(Enumerator)
        .and have_attributes(size: 0)
    end

    it "skips deleted entries" do
      yielded = []
      map.each_pair { |pair| yielded << pair }
      expect(yielded).to contain_exactly([:a, 1], [:b, 2])

      map.delete(:a)
      expect { |b| map.each_pair(&b) }.to yield_with_args([:b, 2])
    end

    it "skips garbage-collected keys" do
      map.clear

      collectable do
        key = +"foo"
        map[key] = 123
        expect { |b| map.each_pair(&b) }.to yield_with_args([key, 123])
      end

      garbage_collect_until do
        expect { |b| map.each_pair(&b) }.not_to yield_control
      end
    end

    it "skips garbage-collected values" do
      map.clear

      collectable do
        value = +"foo"
        map[123] = value
        expect { |b| map.each_pair(&b) }.to yield_with_args([123, value])
      end

      garbage_collect_until do
        expect { |b| map.each_pair(&b) }.not_to yield_control
      end
    end

    it "is aliased to #each" do
      # This is more "manual" because Ruby 3.4 distinguishes the method owner,
      # i.e., the module where the method or alias was defined. In previous
      # Ruby versions, that didn't matter.
      expect(map.method(:each)).to have_attributes(
        owner: Weak::Map,
        source_location: map.method(:each_pair).source_location
      )

      expect { |b| map.each(&b) }.to yield_control.twice
    end
  end

  describe "#each_value" do
    before do
      map[:a] = 1
      map[:b] = 2
    end

    it "calls block once for each key, passing value" do
      map[:c] = nil
      map[:d] = 2

      args = []
      expect(map.each_value { |v| args << v }).to equal map
      expect(args).to contain_exactly(1, 2, nil, 2)
    end

    it "skips deleted entries" do
      yielded = []
      map.each_value { |*args| yielded << args }
      expect(yielded).to contain_exactly([1], [2])

      map.delete(:a)
      expect { |b| map.each_value(&b) }.to yield_with_args(2)
    end

    it "skips garbage-collected keys" do
      map.clear

      collectable do
        key = +"foo"
        map[key] = 123
        expect { |b| map.each_value(&b) }.to yield_with_args(123)
      end

      garbage_collect_until do
        expect { |b| map.each_value(&b) }.not_to yield_control
      end
    end

    it "skips garbage-collected values" do
      map.clear

      collectable do
        value = +"foo"
        map[123] = value
        expect { |b| map.each_value(&b) }.to yield_with_args(value)
      end

      garbage_collect_until do
        expect { |b| map.each_value(&b) }.not_to yield_control
      end
    end

    it "returns an Enumerator if called on a non-empty hash without a block" do
      expect(map.each_value)
        .to be_instance_of(Enumerator)
        .and have_attributes(size: 2)
    end

    it "returns an Enumerator if called on an empty hash without a block" do
      expect(Weak::Map.new.each_value)
        .to be_instance_of(Enumerator)
        .and have_attributes(size: 0)
    end
  end

  describe "#empty?" do
    it "returns false for a populated msp" do
      map[:a] = 1
      expect(map.empty?).to be false
    end

    it "returns true for an empty map" do
      expect(map.empty?).to be true
    end

    it "returns true as elements are garbage collected" do
      collectable do
        key = +"foo"
        map[key] = 123
        expect(map[key]).to eq 123
      end

      garbage_collect_until do
        expect(map.empty?).to be true
      end
    end
  end

  describe "#fetch" do
    it "returns the value for key" do
      map[:a] = 1
      expect(map.fetch(:a)).to eq 1
    end

    it "raises KeyError if the key is not found" do
      expect { map.fetch(:key) }.to raise_error(KeyError) { |e|
        expect(e.receiver).to equal map
        expect(e.key).to eq :key
      }

      map[:a] = 123
      expect { map.fetch(:b) }.to raise_error(KeyError) { |e|
        expect(e.receiver).to equal map
        expect(e.key).to eq :b
      }

      map = Weak::Map.new(5)
      expect { map.fetch(:key) }.to raise_error(KeyError) { |e|
        expect(e.receiver).to equal map
        expect(e.key).to eq :key
      }

      map = Weak::Map.new { 5 }
      expect { map.fetch(:key) }.to raise_error(KeyError) { |e|
        expect(e.receiver).to equal map
        expect(e.key).to eq :key
      }
    end

    it "formats the key with #inspect in the KeyError message" do
      expect { map.fetch("key") }.to raise_error(KeyError) { |e|
        expect(e.message).to eq 'key not found: "key"'
      }
    end

    it "returns default if key is not found when passed a default" do
      expect(map.fetch(:a, nil)).to be_nil
      expect(map.fetch(:a, "not here!")).to eq "not here!"

      map[:a] = nil
      expect(map.fetch(:a, "not here!")).to be_nil
    end

    it "returns value of block if key is not found when passed a block" do
      expect(map.fetch("a") { |k| k + "!" }).to eq "a!"
    end

    it "prefers the default block over the default argument when passed both" do
      expect(map).to receive(:warn)
        .with("warning: block supersedes default value argument")

      expect(map.fetch(9, :foo) { |i| i * i }).to eq 81
    end

    it "raises an ArgumentError when not passed one or two arguments" do
      expect { map.fetch }.to raise_error(ArgumentError)
      expect { map.fetch(1, 2, 3) }.to raise_error(ArgumentError)
    end

    it "skips garbage-collected values" do
      collectable do
        value = +"foo"
        map[123] = value
        expect(map.fetch(123)).to equal value
      end

      garbage_collect_until do
        expect { map.fetch(123) }.to raise_error(KeyError)
      end
    end

    it "skips deleted keys" do
      map[:a] = :b
      expect(map.fetch(:a)).to eq :b

      map.delete(:a)
      expect { map.fetch(:a) }.to raise_error(KeyError)
    end

    it "auto prunes with missing key" do
      expect_prune_on do |map|
        expect(map.fetch(:missing, :default)).to eq :default
      end
    end

    it "auto prunes with an existing key" do
      expect_prune_on do |map|
        expect(map.fetch(:key)).to eq :value
      end
    end
  end

  describe "#freeze" do
    before do
      allow(map).to receive(:warn)
    end

    it "returns self" do
      expect(map.freeze).to equal(map)
    end

    it "does not actually freeze" do
      map.freeze

      expect(map).not_to be_frozen
      expect(map.instance_variables).to all satisfy { |var|
        value = map.instance_variable_get(var)
        value.nil? || !value.frozen?
      }
    end

    it "warns that we can not freeze a Weak::Map" do
      map.freeze
      expect(map).to have_received(:warn).with("Can't freeze Weak::Map")
    end
  end

  describe "#has_value?" do
    it "returns true if the value exists in the map" do
      map[:a] = :b
      expect(map.has_value?(:a)).to be false
      expect(map.has_value?(:b)).to be true
    end

    it "ignores map defaults" do
      expect(Weak::Map.new(5).has_value?(5)).to be false
      expect(Weak::Map.new { 5 }.has_value?(5)).to be false
    end

    it "checks object identity" do
      k1 = +"foo"
      k2 = +"foo"
      expect(k1).not_to equal k2

      map[:k1] = k1
      expect(map.has_value?(k1)).to be true
      expect(map.has_value?(k2)).to be false
    end

    it "is aliased to #value?" do
      expect(map.method(:value?)).to eq map.method(:has_value?)

      map[:foo] = :bar
      expect(map.value?(:foo)).to be false
      expect(map.value?(:bar)).to be true
    end
  end

  describe "#include?" do
    it "returns true if argument is a key" do
      map[:a] = 1
      map[:b] = 2
      expect(map.include?(:a)).to be true
      expect(map.include?(:b)).to be true
      expect(map.include?(2)).to be false
      expect(map.include?(:missing)).to be false

      expect(map.include?("b")).to be false
      expect(map.include?(4.0)).to be false
    end

    it "returns true if the value is nil" do
      map[:xyz] = nil
      expect(map.include?(:xyz)).to be true
    end

    it "returns true if the value is false" do
      map[:xyz] = false
      expect(map.include?(:xyz)).to be true
    end

    it "returns true if the key is nil" do
      map[nil] = nil
      expect(map.include?(nil)).to be true
    end

    it "checks object identity" do
      k1 = +"foo"
      k2 = +"foo"
      expect(k1).to eql k2

      map[k1] = :a
      expect(map.include?(k1)).to be true
      expect(map.include?(k2)).to be false
    end

    it "skips deleted values" do
      map[:a] = :b
      expect(map.include?(:a)).to be true

      map.delete(:a)
      expect(map.include?(:a)).to be false
    end

    it "skips garbage-collected values" do
      collectable do
        value = +"foo"
        map[123] = value
        expect(map.include?(123)).to be true
      end

      garbage_collect_until do
        expect(map.include?(123)).to be false
      end
    end

    it "auto prunes with a missing key" do
      expect_prune_on do |map|
        expect(map.include?(:missing)).to be false
      end
    end

    it "auto prunes with an existing key" do
      expect_prune_on do |map|
        expect(map.include?(:key)).to be true
      end
    end

    it "is aliased to #has_key?" do
      # This is more "manual" because Ruby 3.4 distinguishes the method owner,
      # i.e., the module where the method or alias was defined. In previous
      # Ruby versions, that didn't matter.
      expect(map.method(:has_key?)).to have_attributes(
        owner: Weak::Map,
        source_location: map.method(:include?).source_location
      )

      map[:foo] = :bar
      expect(map.has_key?(:foo)).to be true
      expect(map.has_key?(:bar)).to be false
    end

    it "is aliased to #key?" do
      # This is more "manual" because Ruby 3.4 distinguishes the method owner,
      # i.e., the module where the method or alias was defined. In previous
      # Ruby versions, that didn't matter.
      expect(map.method(:key?)).to have_attributes(
        owner: Weak::Map,
        source_location: map.method(:include?).source_location
      )

      map[:foo] = :bar
      expect(map.key?(:foo)).to be true
      expect(map.key?(:bar)).to be false
    end

    it "is aliased to #member?" do
      # This is more "manual" because Ruby 3.4 distinguishes the method owner,
      # i.e., the module where the method or alias was defined. In previous
      # Ruby versions, that didn't matter.
      expect(map.method(:member?)).to have_attributes(
        owner: Weak::Map,
        source_location: map.method(:include?).source_location
      )

      map[:foo] = :bar
      expect(map.member?(:foo)).to be true
      expect(map.member?(:bar)).to be false
    end
  end

  describe "#inspect" do
    before do
      map[1] = :a
      map[2] = :b
    end

    it "shows details" do
      if Gem::Requirement.new("< 3.4.0") === Gem.ruby_version
        expect(map.inspect).to eq "#<Weak::Map {1=>:a, 2=>:b}>"
      else
        expect(map.inspect).to eq "#<Weak::Map {1 => :a, 2 => :b}>"
      end
    end

    it "uses the Ruby's Hash #inspect logic for symbol keys" do
      map[:a] = 9

      if Gem::Requirement.new("< 3.4.0") === Gem.ruby_version
        expect(map.inspect).to include ":a=>9"
      else
        expect(map.inspect).to include "a: 9"
      end
    end

    it "inspects nested maps" do
      nested = Weak::Map.new
      nested[3] = map

      if Gem::Requirement.new("< 3.4.0") === Gem.ruby_version
        expect(nested.inspect).to eq "#<Weak::Map {3=>#<Weak::Map {1=>:a, 2=>:b}>}>"
      else
        expect(nested.inspect).to eq "#<Weak::Map {3 => #<Weak::Map {1 => :a, 2 => :b}>}>"
      end
    end

    it "handles infinite recursion" do
      map[3] = map

      if Gem::Requirement.new("< 3.4.0") === Gem.ruby_version
        expect(map.inspect)
          .to eq "#<Weak::Map {1=>:a, 2=>:b, 3=>#<Weak::Map {...}>}>"
      else
        expect(map.inspect)
          .to eq "#<Weak::Map {1 => :a, 2 => :b, 3 => #<Weak::Map {...}>}>"
      end
    end

    it "does not swallow nested exceptions" do
      errored = Class.new do
        def inspect
          raise("Oh Noes!")
        end
      end.new
      map[:a] = errored

      expect { map.inspect }.to raise_error(RuntimeError, "Oh Noes!")
    end

    it "is aliased to #to_s" do
      expect(map.method(:to_s)).to eq map.method(:inspect)

      if Gem::Requirement.new("< 3.4.0") === Gem.ruby_version
        expect(map.to_s).to eq "#<Weak::Map {1=>:a, 2=>:b}>"
      else
        expect(map.to_s).to eq "#<Weak::Map {1 => :a, 2 => :b}>"
      end
    end
  end

  describe "#keep_if" do
    before do
      map.merge!({a: 1, b: 3, c: 1, d: 2, e: 5})
    end

    it "yields two arguments: key and value" do
      all_args = []
      map.keep_if { |*args| all_args << args }
      expect(all_args.sort).to eq [[:a, 1], [:b, 3], [:c, 1], [:d, 2], [:e, 5]]
    end

    it "keeps every entry for which block is true and returns self" do
      expect(map.keep_if { |k, v| v % 2 == 0 })
        .to equal(map)
        .and have_attributes(
          to_h: {d: 2}.compare_by_identity
        )
    end

    it "removes all entries if the block is false" do
      expect(map.keep_if { |_k, _v| false })
        .to equal(map)
        .and be_empty
    end

    it "returns self even if unmodified" do
      expect(map.keep_if { true }).to equal(map)
    end

    it "returns an Enumerator if called on a non-empty map without a block" do
      expect(map.keep_if)
        .to be_an_instance_of(Enumerator)
        .and have_attributes(size: 5)
    end

    it "returns an Enumerator if called on an empty map without a block" do
      expect(Weak::Map.new.keep_if)
        .to be_an_instance_of(Enumerator)
        .and have_attributes(size: 0)
    end
  end

  describe "#keys" do
    it "returns an array with the keys" do
      expect(Weak::Map.new.keys).to be_instance_of(Array).and be_empty

      expect(Weak::Map.new(5).keys).to be_instance_of(Array).and be_empty
      expect(Weak::Map.new { 5 }.keys).to be_instance_of(Array).and be_empty

      map[1] = 2
      map[4] = 8
      map[2] = 4
      map[nil] = nil
      expect(map.keys).to be_instance_of(Array).and contain_exactly(1, 2, 4, nil)
    end

    it "skips deleted entries" do
      key = +"foo"
      map[key] = 123
      expect(map.keys).to include(key)

      map.delete(key)
      expect(map.keys).to be_empty
    end

    it "skips garbage-collected keys" do
      collectable do
        key = +"foo"
        map[key] = 123
        expect(map[key]).to eq 123
      end

      garbage_collect_until do
        expect(map.keys).to be_empty
      end
    end

    it "skips keys with garbage-collected values" do
      collectable do
        foo = +"foo"
        map[123] = foo
        expect(map.keys).to eq [123]
      end

      garbage_collect_until do
        expect(map.keys).to be_empty
      end
    end
  end

  describe "#merge" do
    it "adds the entries from other, overwriting duplicate keys" do
      map[:a] = 1
      map[:b] = 2

      expect(map.merge(a: :a, z: 2))
        .to be_a(Weak::Map)
        .and not_equal(map)
        .and have_attributes(
          to_h: {a: :a, b: 2, z: 2}.compare_by_identity
        )

      expect(map.to_h).to eq({a: 1, b: 2}.compare_by_identity)
    end

    it "sets any duplicate key to the value of block if passed a block" do
      m1 = Weak::Map.new
      m1[:a] = 2
      m1[:b] = -1
      m1[:c] = nil

      m2 = Weak::Map.new
      m2[:a] = -2
      m2[:d] = 1

      expect(m1.merge(m2) { |k, x, y| 3.14 })
        .to be_a(Weak::Map)
        .and not_equal(m1)
        .and not_equal(m2)
        .and have_attributes(
          to_h: {a: 3.14, b: -1, c: nil, d: 1}.compare_by_identity
        )
      expect(m1.to_h).to eq({a: 2, b: -1, c: nil}.compare_by_identity)

      expect(m1.merge(m1) { nil })
        .to be_a(Weak::Map)
        .and not_equal(m1)
        .and have_attributes(
          to_h: {a: nil, b: nil, c: nil}.compare_by_identity
        )
    end

    it "accepts multiple hashes" do
      map[:a] = 1

      expect(map.merge({b: 2}, {c: 3}, {d: 4}))
        .to be_a(Weak::Map)
        .and not_equal(map)
        .and have_attributes(
          to_h: {a: 1, b: 2, c: 3, d: 4}.compare_by_identity
        )
    end

    it "accepts zero arguments and returns a copy of self" do
      map[:a] = 1
      expect(map.merge)
        .to be_a(Weak::Map)
        .and not_equal(map)
        .and have_attributes(to_h: {a: 1}.compare_by_identity)
    end

    it "matches keys by object identity" do
      k1 = +"foo"
      k2 = +"foo"
      expect(k1).not_to equal k2

      map[k1] = 1
      expect(map.update({k2 => 2})).to equal map
      expect(map.size).to eq 2
    end

    it "is aliased to #merge!" do
      expect(map.method(:merge!)).to eq map.method(:update)
      expect(map.merge!({a: 1}, {b: 2}, {a: 3}))
        .to equal(map)
        .and have_attributes(
          to_h: {a: 3, b: 2}.compare_by_identity
        )
    end
  end

  describe "#pretty_print" do
    before do
      map[1] = :a
      map[2] = :b
    end

    it "pretty prints wide" do
      expect(map).to receive(:pretty_print).with(PP).and_call_original
      expect(PP.pp(map, +"", 80)).to eq "#{map.inspect}\n"
    end

    it "pretty prints medium wide" do
      expect(map).to receive(:pretty_print).with(PP).and_call_original

      if Gem::Requirement.new("< 3.4.0") === Gem.ruby_version
        expect(PP.pp(map, +"", 20)).to eq <<~PP
          #<Weak::Map
           {1=>:a, 2=>:b}>
        PP
      else
        expect(PP.pp(map, +"", 20)).to eq <<~PP
          #<Weak::Map
           {1 => :a, 2 => :b}>
        PP
      end
    end

    it "pretty prints narrow" do
      expect(map).to receive(:pretty_print).with(PP).and_call_original

      if Gem::Requirement.new("< 3.4.0") === Gem.ruby_version
        expect(PP.pp(map, +"", 12)).to eq <<~PP
          #<Weak::Map
           {1=>:a,
            2=>:b}>
        PP
      else
        expect(PP.pp(map, +"", 12)).to eq <<~PP
          #<Weak::Map
           {1 => :a,
            2 => :b}>
        PP
      end
    end
  end

  describe "#prune" do
    it "returns self" do
      expect(map.prune).to equal map
    end

    it "garbage collects internal data" do
      next unless strategy?("StrongKeys", "StrongSecondaryKeys")

      collectable do
        key = +"foo"
        map[key] = 123

        expect(map.instance_variable_get(:@keys).size).to eq 1
        expect(map.instance_variable_get(:@values).size).to eq 1
        if strategy?("StrongSecondaryKeys")
          expect(map.instance_variable_get(:@key_map).size).to eq 1
        end
      end

      garbage_collect_until do
        expect(map.instance_variable_get(:@keys).size).to eq 0
      end
      expect(map.instance_variable_get(:@values).size).to eq 1
      if strategy?("StrongSecondaryKeys")
        expect(map.instance_variable_get(:@key_map).size).to eq 1
      end

      map.prune

      expect(map.instance_variable_get(:@keys).size).to eq 0
      if strategy?("StrongSecondaryKeys")
        expect(map.instance_variable_get(:@key_map).size).to eq 0
      end
      garbage_collect_until do
        # The value will be marked as a DeletedEntry.
        expect(map.instance_variable_get(:@values).size).to eq 0
      end
    end
  end

  describe "#reject!" do
    before do
      map.merge!({a: 1, b: 3, c: 1, d: 2, e: 5})
    end

    it "yields two arguments: key and value" do
      all_args = []
      map.reject! { |*args| all_args << args }
      expect(all_args.sort).to eq [[:a, 1], [:b, 3], [:c, 1], [:d, 2], [:e, 5]]
    end

    it "returns self if any changes were made" do
      expect(map.reject! { |k, v| v > 3 })
        .to equal(map)
        .and have_attributes(
          values: contain_exactly(1, 3, 1, 2)
        )
    end

    it "returns nil if no changes were made" do
      expect(map.reject! { |_k, v| v > 10 }).to be_nil
      expect(map.reject! { |_k, v| false }).to be_nil
    end

    it "removes all entries if the block is true" do
      expect(map.reject! { |_k, _v| true })
        .to equal(map)
        .and be_empty
    end

    it "returns an Enumerator if called on a non-empty map without a block" do
      expect(map.reject!)
        .to be_an_instance_of(Enumerator)
        .and have_attributes(size: 5)
    end

    it "returns an Enumerator if called on an empty map without a block" do
      expect(Weak::Map.new.reject!)
        .to be_an_instance_of(Enumerator)
        .and have_attributes(size: 0)
    end
  end

  describe "select!" do
    before do
      map.merge!({a: 1, b: 3, c: 1, d: 2, e: 5})
    end

    it "yields two arguments: key and value" do
      all_args = []
      map.select! { |*args| all_args << args }
      expect(all_args.sort).to eq [[:a, 1], [:b, 3], [:c, 1], [:d, 2], [:e, 5]]
    end

    it "returns self if any changes were made" do
      expect(map.select! { |k, v| v < 5 })
        .to equal(map)
        .and have_attributes(
          values: contain_exactly(1, 3, 1, 2)
        )
    end

    it "returns nil if no changes were made" do
      expect(map.select! { |_k, v| v < 10 }).to be_nil
    end

    it "removes all entries if the block is false" do
      expect(map.select! { |_k, _v| false })
        .to equal(map)
        .and be_empty
    end

    it "returns an Enumerator if called on a non-empty map without a block" do
      expect(map.select!)
        .to be_an_instance_of(Enumerator)
        .and have_attributes(size: 5)
    end

    it "returns an Enumerator if called on an empty map without a block" do
      expect(Weak::Map.new.select!)
        .to be_an_instance_of(Enumerator)
        .and have_attributes(size: 0)
    end

    it "is aliased to #filter!" do
      expect(map.method(:filter!)).to eq map.method(:select!)

      expect(map.filter! { |k, v| k.is_a?(Symbol) }).to be_nil
      expect(map.to_h).to eq({a: 1, b: 3, c: 1, d: 2, e: 5}.compare_by_identity)

      expect(map.filter! { |_k, v| v < 5 })
        .to equal(map)
        .and have_attributes(
          values: contain_exactly(1, 3, 1, 2)
        )
    end
  end

  describe "#size" do
    it "returns the number of entries" do
      expect(map.size).to eq 0

      map[:a] = 1
      map[:b] = 2
      expect(map.size).to eq 2

      map[:a] = 2
      expect(map.size).to eq 2

      map.delete(:a)
      expect(map.size).to eq 1
    end

    it "skips garbage-collected keys" do
      collectable do
        key = +"foo"
        map[key] = 123
        expect(map.size).to eq 1
      end

      garbage_collect_until do
        expect(map.size).to eq 0
      end
    end

    it "skips garbage-collected values" do
      collectable do
        value = +"foo"
        map[123] = value
        expect(map.size).to eq 1
      end

      garbage_collect_until do
        expect(map.size).to eq 0
      end
    end

    it "is not affected by default values" do
      expect(Weak::Map.new(5).size).to eq 0
      expect(Weak::Map.new { 5 }.size).to eq 0
    end

    it "is aliased to #length" do
      # This is more "manual" because Ruby 3.4 distinguishes the method owner,
      # i.e., the module where the method or alias was defined. In previous
      # Ruby versions, that didn't matter.
      expect(map.method(:length)).to have_attributes(
        owner: Weak::Map,
        source_location: map.method(:size).source_location
      )

      expect(map.length).to eq 0
      map[:foo] = :bar
      expect(map.length).to eq 1
    end
  end

  describe "#update" do
    it "adds the entries from other, overwriting duplicate keys. Returns self" do
      map[:a] = 1
      map[:b] = 2

      expect(map.update(a: :a, z: 2)).to equal map
      expect(map.to_h).to eq({a: :a, b: 2, z: 2}.compare_by_identity)
    end

    it "sets any duplicate key to the value of block if passed a block" do
      m1 = Weak::Map.new
      m1[:a] = 2
      m1[:b] = -1
      m1[:c] = nil

      m2 = Weak::Map.new
      m2[:a] = -2
      m2[:d] = 1

      expect(m1.update(m2) { |k, x, y| 3.14 }).to equal m1
      expect(m1.to_h).to eq({a: 3.14, b: -1, c: nil, d: 1}.compare_by_identity)

      expect(m1.update(m1) { nil }).to equal m1
      expect(m1.to_h).to eq({a: nil, b: nil, c: nil, d: nil}.compare_by_identity)
    end

    it "does not raise an exception if changing the value of an existing key during iteration" do
      m1 = Weak::Map.new
      m1[1] = 2
      m1[3] = 4
      m1[5] = 6

      m2 = Weak::Map.new
      m1[1] = :foo
      m1[3] = :bar

      m1.each { m1.update(m2) }
      expect(m1.to_h).to eq({1 => :foo, 3 => :bar, 5 => 6}.compare_by_identity)
    end

    it "accepts multiple hashes" do
      map[:a] = 1

      expect(map.update({b: 2}, {c: 3}, {d: 4}))
        .to equal(map)
        .and have_attributes(
          to_h: {a: 1, b: 2, c: 3, d: 4}.compare_by_identity
        )
    end

    it "accepts zero arguments" do
      map[:a] = 1
      expect(map.update).to equal(map)
    end

    it "matches keys by object identity" do
      k1 = +"foo"
      k2 = +"foo"
      expect(k1).not_to equal k2

      map[k1] = 1
      expect(map.update({k2 => 2})).to equal map
      expect(map.size).to eq 2
    end

    it "is aliased to #merge!" do
      expect(map.method(:merge!)).to eq map.method(:update)
      expect(map.merge!({a: 1}, {b: 2}, {a: 3}))
        .to equal(map)
        .and have_attributes(
          to_h: {a: 3, b: 2}.compare_by_identity
        )
    end
  end

  describe "#values" do
    it "returns an array of values" do
      a = +"a"
      b = +"b"

      map[1] = 123
      map[:a] = a
      map[b] = b
      map[:c] = nil
      map[:d] = a

      expect(map.values)
        .to be_instance_of(Array)
        .and contain_exactly(123, a, b, nil, a)
    end

    it "skips garbage-collected keys" do
      collectable do
        key = +"foo"
        map[key] = 123
        expect(map.values).to eq [123]
      end

      garbage_collect_until do
        expect(map.values).to be_empty
      end
    end

    it "skips garbage-collected values" do
      collectable do
        value = +"foo"
        map[123] = value
        expect(map.values).to eq [value]
      end

      garbage_collect_until do
        expect(map.values).to be_empty
      end
    end

    it "skips deleted values" do
      map[123] = :a
      expect(map.values).to include(:a)

      map.delete(123)
      expect(map.values).to be_empty
    end
  end

  describe "#to_a" do
    it "returns an Array of elements" do
      map[:a] = 1
      map[:b] = 2
      map[:c] = 3

      expect(map.to_a)
        .to be_instance_of(Array)
        .and contain_exactly([:a, 1], [:b, 2], [:c, 3])
    end

    it "skips deleted entries" do
      map[:a] = 123
      expect(map.to_a).to include([:a, 123])

      map.delete(:a)
      expect(map.to_a).to be_empty
    end

    it "skips garbage-collected entries" do
      collectable do
        key = +"foo"
        value = +"bar"
        map[key] = value

        expect(map[key]).to equal value
        expect(map).not_to be_empty
      end

      garbage_collect_until do
        expect(map.to_a).to be_empty
      end
    end
  end

  describe "#to_h" do
    it "returns an Hash of elements" do
      map[:a] = 1
      map[:b] = 2
      map[:c] = 3

      expect(map.to_h)
        .to be_instance_of(Hash)
        .and be_compare_by_identity
        .and eq(
          {a: 1, b: 2, c: 3}.compare_by_identity
        )
    end

    it "skips deleted entries" do
      map[:a] = 123
      expect(map.to_h[:a]).to eq 123

      map.delete(:a)
      expect(map.to_h).to be_empty
    end

    it "skips garbage-collected entries" do
      collectable do
        key = +"foo"
        value = +"bar"
        map[key] = value

        expect(map[key]).to equal value
        expect(map).not_to be_empty
      end

      garbage_collect_until do
        expect(map.to_h).to be_empty
      end
    end

    context "with block" do
      before do
        map[:a] = 1
        map[:b] = 2
      end

      it "converts [key, value] pairs returned by the block to a hash" do
        expect(map.to_h { |k, v| [k.upcase, v * v] }).to eq(
          {A: 1, B: 4}.compare_by_identity
        )
      end

      it "passes to a block each pair's key and value as separate arguments" do
        yielded_args = []
        map.to_h { |k, v|
          yielded_args << [k, v]
          [k, v]
        }
        expect(yielded_args).to contain_exactly([:a, 1], [:b, 2])

        yielded_args = []
        map.to_h { |*args|
          yielded_args << args
          args
        }
        expect(yielded_args).to contain_exactly([:a, 1], [:b, 2])
      end

      it "raises ArgumentError if block returns longer or shorter array" do
        expect { map.to_h { |k, v| [k.to_s, v * v, 1] } }
          .to raise_error(ArgumentError, /element has wrong array length/)

        expect { map.to_h { |k, v| [k] } }
          .to raise_error(ArgumentError, /element has wrong array length/)
      end

      it "raises TypeError if block returns something other than Array" do
        expect { map.to_h { |k, v| "not-array" } }
          .to raise_error(TypeError, /wrong element type String/)
      end

      it "coerces returned pair to Array with #to_ary" do
        ary = instance_double(Array, to_ary: [:b, "b"])
        expect(map.to_h { |k, v| ary }).to eq(
          {b: "b"}.compare_by_identity
        )
      end

      it "does not coerce returned pair to Array with #to_a" do
        ary = instance_double(Array, to_a: [:b, "b"])

        expect { map.to_h { |k, v| ary } }
          .to raise_error(TypeError, /wrong element type/)
      end
    end
  end

  describe "#values_at" do
    before do
      map.merge!(a: 9, b: :a, c: -10, d: nil)
    end

    it "returns an Array" do
      expect(map.values_at).to be_instance_of(::Array).and eq([])
    end

    it "returns valeus in order" do
      expect(map.values_at(:a, :d, :b))
        .to be_instance_of(::Array)
        .and eq([9, nil, :a])
    end

    it "returns default values" do
      map.default = 123
      expect(map.values_at("missing", :a))
        .to be_instance_of(::Array)
        .and eq([123, 9])
    end

    it "returns default_proc values" do
      map.default_proc = ->(map, key) { key * 2 }
      expect(map.values_at(:b, 21))
        .to be_instance_of(::Array)
        .and eq([:a, 42])
    end
  end
end
