# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require "spec_helper"

RSpec.describe Weak::Cache do
  let(:cache) { Weak::Cache.new }

  describe "#initialize" do
    it "returns a Weak::Map" do
      expect(Weak::Cache.new).to be_instance_of Weak::Cache
    end
  end

  describe "#clear" do
    it "clears the cache" do
      cache[:a] = 1
      expect(cache.clear).to equal(cache).and be_empty
    end
  end

  describe "#clone" do
    it "clones the cache" do
      cache[:foo] = 1

      expect(cache.clone)
        .to be_a(Weak::Cache)
        .and not_equal(cache)
        .and have_attributes(to_h: {foo: 1}.compare_by_identity)
    end

    it "clones the internal map" do
      cache[:foo] = 1

      clone = cache.clone
      clone[:bar] = 2
      clone.delete(:foo)

      expect(cache.to_h).to eq({foo: 1}.compare_by_identity)
      expect(clone.to_h).to eq({bar: 2}.compare_by_identity)
    end

    it "allows to use freeze: false" do
      cache[:foo] = 1

      expect(cache.clone(freeze: false))
        .to be_a(Weak::Cache)
        .and not_be_frozen
        .and not_equal(cache)
        .and have_attributes(to_h: {foo: 1}.compare_by_identity)
    end

    it "ignores freeze: true" do
      allow(cache).to receive(:warn)

      cache[:foo] = 1
      expect(cache.clone(freeze: true))
        .to be_a(Weak::Cache)
        .and not_be_frozen
        .and not_equal(cache)
        .and have_attributes(to_h: {foo: 1}.compare_by_identity)

      expect(cache).to have_received(:warn).with("Can't freeze Weak::Cache")

      # Instance variables of the cloned map won't be frozen either
      expect(cache.clone(freeze: true).instance_variables).to all satisfy { |var|
        value = cache.instance_variable_get(var)
        !value.frozen?
      }
    end

    it "duplicates the mutex" do
      clone = cache.clone

      expect(clone.instance_variable_get(:@mutex))
        .to be_a(Mutex)
        .and not_equal(cache.instance_variable_get(:@mutex))
    end
  end

  describe "#delete" do
    it "returns true when deleting an entry" do
      cache[:a] = 5
      expect(cache.delete(:a)).to be true
      expect(cache.to_h).to be_empty
    end

    it "returns false if an entry was not found" do
      cache[:a] = 5

      expect(cache.delete(:b)).to be false
      expect(cache.to_h).to match(a: 5)

      expect(cache.delete(:a)).to be true
      expect(cache.delete(:a)).to be false
      expect(cache.to_h).to be_empty
    end

    it "checks keys by object identity" do
      k1 = +"foo"
      k2 = +"foo"
      expect(k1).not_to equal k2

      cache[k1] = :k1
      cache[k2] = :k2
      expect(cache.size).to eq 2

      expect(cache.delete(k1)).to be true
      expect(cache.size).to eq 1

      expect(cache.delete(k1)).to be false
      expect(cache.size).to eq 1

      expect(cache.delete(k2)).to be true
      expect(cache).to be_empty
    end
  end

  describe "#dup" do
    it "duplicates the cache" do
      cache[:foo] = 1
      expect(cache.dup)
        .to be_a(Weak::Cache)
        .and not_equal(cache)
        .and not_be_frozen
        .and have_attributes(to_h: {foo: 1}.compare_by_identity)

      dup = cache.dup
      dup[:bar] = 2
      dup.delete(:foo)

      expect(cache.to_h).to eq({foo: 1}.compare_by_identity)
      expect(dup.to_h).to eq({bar: 2}.compare_by_identity)
    end

    it "duplicates the mutex" do
      dup = cache.dup

      expect(dup.instance_variable_get(:@mutex))
        .to be_a(Mutex)
        .and not_equal(cache.instance_variable_get(:@mutex))
    end
  end

  describe "#each_key" do
    before do
      cache[:a] = 1
      cache[:b] = 2
    end

    it "calls block once for each key" do
      cache[:c] = nil
      cache[nil] = 2

      yielded = []
      expect(cache.each_key { |*args| yielded << args }).to equal cache
      expect(yielded).to contain_exactly([:a], [:b], [:c], [nil])
    end

    it "skips deleted entries" do
      yielded = []
      cache.each_key { |*args| yielded << args }
      expect(yielded).to contain_exactly([:a], [:b])

      cache.delete(:a)
      expect { |b| cache.each_key(&b) }.to yield_with_args(:b)
    end
  end

  describe "#empty?" do
    it "returns false for a populated cache" do
      cache[:a] = 1
      expect(cache.empty?).to be false
    end

    it "returns true for an empty cache" do
      expect(cache.empty?).to be true
    end

    it "returns true as elements are garbage collected" do
      collectable do
        key = +"foo"
        cache[key] = 123
        expect(cache[key]).to eq 123
      end

      garbage_collect_until do
        expect(cache.empty?).to be true
      end
    end
  end

  describe "#exist?" do
    it "returns true if argument is a key" do
      cache[:a] = 1
      cache[:b] = 2
      expect(cache.exist?(:a)).to be true
      expect(cache.exist?(:b)).to be true
      expect(cache.exist?(2)).to be false
      expect(cache.exist?(:missing)).to be false

      expect(cache.exist?("b")).to be false
      expect(cache.exist?(4.0)).to be false
    end

    it "returns true if the value is nil" do
      cache[:xyz] = nil
      expect(cache.exist?(:xyz)).to be true
    end

    it "returns true if the value is false" do
      cache[:xyz] = false
      expect(cache.exist?(:xyz)).to be true
    end

    it "returns true if the key is nil" do
      cache[nil] = nil
      expect(cache.exist?(nil)).to be true
    end

    it "checks object identity" do
      k1 = +"foo"
      k2 = +"foo"
      expect(k1).to eql k2

      cache[k1] = :a
      expect(cache.exist?(k1)).to be true
      expect(cache.exist?(k2)).to be false
    end

    it "skips deleted values" do
      cache[:a] = :b
      expect(cache.exist?(:a)).to be true

      cache.delete(:a)
      expect(cache.exist?(:a)).to be false
    end

    it "skips garbage-collected values" do
      collectable do
        value = +"foo"
        cache[123] = value
        expect(cache.exist?(123)).to be true
      end

      garbage_collect_until do
        expect(cache.exist?(123)).to be false
      end
    end

    it "is aliased to #include?" do
      expect(cache.method(:include?)).to eq cache.method(:exist?)

      cache[:xyz] = 123
      expect(cache.include?(:xyz)).to be true
      expect(cache.include?(:abc)).to be false
    end

    it "is aliased to #key?" do
      expect(cache.method(:key?)).to eq cache.method(:exist?)

      cache[:xyz] = 123
      expect(cache.key?(:xyz)).to be true
      expect(cache.key?(:abc)).to be false
    end
  end

  describe "#fetch" do
    it "returns the value for key" do
      cache[:a] = 1
      expect(cache.fetch(:a) {}).to eq 1
    end

    it "requires a block" do
      cache[:a] = 1
      expect { cache.fetch(:a) }.to raise_error ArgumentError
      expect { cache.fetch(:b) }.to raise_error ArgumentError
    end

    it "returns value of block if key is not found" do
      expect(cache.fetch("a") { |k| k + "!" }).to eq "a!"
    end

    it "skips garbage-collected values" do
      collectable do
        value = +"foo"
        cache[123] = value
        expect(cache.fetch(123) { :missing }).to equal value
      end

      garbage_collect_until do
        expect(cache.fetch(123) { :missing }).to eq :missing
      end
    end

    it "skips deleted keys" do
      cache[:a] = :b
      expect(cache.fetch(:a) { :missing }).to eq :b

      cache.delete(:a)
      expect(cache.fetch(:a) { :missing }).to eq :missing
    end

    it "writes the block value on cache miss" do
      expect(cache.size).to eq 0

      expect(cache.fetch(:a) { :value }).to eq :value

      expect(cache.size).to eq 1
      expect(cache.fetch(:a) { :mising }).to eq :value
    end

    it "writes nil values by default" do
      expect(cache.fetch(:a) { nil }).to be_nil
      expect(cache.size).to eq 1
      expect(cache.exist?(:a)).to be true
    end

    it "does not write nil values with skip_nil" do
      expect(cache.fetch(:a, skip_nil: true) { nil }).to be_nil
      expect(cache.size).to eq 0
      expect(cache.exist?(:a)).to be false
    end

    it "returns existing nil values with skip_nil" do
      cache[:a] = nil
      expect(cache.fetch(:a, skip_nil: true) { :mising }).to be_nil
      expect(cache[:a]).to be_nil
    end
  end

  describe "#freeze" do
    before do
      allow(cache).to receive(:warn)
    end

    it "returns self" do
      expect(cache.freeze).to equal(cache)
    end

    it "does not actually freeze" do
      cache.freeze

      expect(cache).not_to be_frozen
      expect(cache.instance_variables).to all satisfy { |var|
        value = cache.instance_variable_get(var)
        !value.frozen?
      }
    end

    it "warns that we can not freeze a Weak::Map" do
      cache.freeze
      expect(cache).to have_received(:warn).with("Can't freeze Weak::Cache")
    end
  end

  describe "#keys" do
    it "returns an array with the keys" do
      expect(cache.keys).to be_instance_of(Array).and be_empty

      cache[1] = 2
      cache[4] = 8
      cache[2] = 4
      cache[nil] = nil
      expect(cache.keys).to be_instance_of(Array).and contain_exactly(1, 2, 4, nil)
    end
  end

  describe "#pretty_print" do
    before do
      cache[1] = :a
      cache[2] = :b
    end

    it "pretty prints wide" do
      expect(cache).to receive(:pretty_print).with(PP).and_call_original
      expect(PP.pp(cache, +"", 80)).to eq "#{cache.inspect}\n"
    end

    it "pretty prints medium wide" do
      expect(cache).to receive(:pretty_print).with(PP).and_call_original

      if Gem::Requirement.new("< 3.4.0") === Gem.ruby_version
        expect(PP.pp(cache, +"", 20)).to eq <<~PP
          #<Weak::Cache
           {1=>:a, 2=>:b}>
        PP
      else
        expect(PP.pp(cache, +"", 20)).to eq <<~PP
          #<Weak::Cache
           {1 => :a, 2 => :b}>
        PP
      end
    end

    it "pretty prints narrow" do
      expect(cache).to receive(:pretty_print).with(PP).and_call_original

      if Gem::Requirement.new("< 3.4.0") === Gem.ruby_version
        expect(PP.pp(cache, +"", 12)).to eq <<~PP
          #<Weak::Cache
           {1=>:a,
            2=>:b}>
        PP
      else
        expect(PP.pp(cache, +"", 12)).to eq <<~PP
          #<Weak::Cache
           {1 => :a,
            2 => :b}>
        PP
      end
    end
  end

  describe "#pretty_print_cycle" do
    let(:nested_keys_cache) {
      cache = Weak::Cache.new
      cache[1] = :a
      cache[cache] = :b

      cache
    }

    let(:nested_values_cache) {
      cache = Weak::Cache.new
      cache[1] = :a
      cache[2] = cache

      cache
    }

    it "pretty prints maps with nested keys" do
      expect(nested_keys_cache)
        .to receive(:pretty_print_cycle).with(PP)
        .and_call_original

      if Gem::Requirement.new("< 3.4.0") === Gem.ruby_version
        expect(PP.pp(nested_keys_cache, +"", 30)).to eq <<~PP
          #<Weak::Cache
           {1=>:a,
            #<Weak::Cache {...}>=>:b}>
        PP
      else
        expect(PP.pp(nested_keys_cache, +"", 30)).to eq <<~PP
          #<Weak::Cache
           {1 => :a,
            #<Weak::Cache {...}> => :b}>
        PP
      end
    end

    it "pretty prints maps with nested values" do
      expect(nested_values_cache)
        .to receive(:pretty_print_cycle).with(PP)
        .and_call_original

      if Gem::Requirement.new("< 3.4.0") === Gem.ruby_version
        expect(PP.pp(nested_values_cache, +"", 30)).to eq <<~PP
          #<Weak::Cache
           {1=>:a,
            2=>#<Weak::Cache {...}>}>
        PP
      else
        expect(PP.pp(nested_values_cache, +"", 30)).to eq <<~PP
          #<Weak::Cache
           {1 => :a,
            2 => #<Weak::Cache {...}>}>
        PP
      end
    end
  end

  describe "#read" do
    it "returns the value for a key" do
      obj = instance_double(String)
      foo = +"foo"
      bar = +"bar"
      bar2 = +"bar"
      baz = +"baz"
      cache[1] = 2
      cache[3] = 4
      cache[foo] = bar
      cache[obj] = obj
      cache[bar] = nil
      cache[bar2] = :bar2
      cache[nil] = 5
      cache[false] = 6
      cache[:sym] = baz

      expect(cache.read(1)).to eq 2
      expect(cache.read(3)).to eq 4
      expect(cache.read(foo)).to equal bar
      expect(cache.read(obj)).to equal obj
      expect(cache.read(bar)).to be_nil
      expect(cache.read(bar2)).to eq :bar2
      expect(cache.read(nil)).to eq 5
      expect(cache.read(false)).to eq 6
      expect(cache.read(:sym)).to equal baz
    end

    it "returns nil as default value" do
      cache[0] = 0
      expect(cache.read(5)).to be_nil
      expect(cache.read(nil)).to be_nil
    end

    it "is aliased to #[]" do
      expect(cache.method(:[])).to eq cache.method(:read)

      cache[:a] = 123
      expect(cache[:a]).to eq 123
    end
  end

  describe "#size" do
    it "returns the number of entries" do
      expect(cache.size).to eq 0

      cache[:a] = 1
      cache[:b] = 2
      expect(cache.size).to eq 2

      cache[:a] = 2
      expect(cache.size).to eq 2

      cache.delete(:a)
      expect(cache.size).to eq 1
    end

    it "is aliased to #length" do
      expect(cache.method(:length)).to eq cache.method(:size)

      expect(cache.length).to eq 0
      cache[:a] = 1
      expect(cache.length).to eq 1
    end
  end

  describe "#to_h" do
    it "returns an Hash of elements" do
      cache[:a] = 1
      cache[:b] = 2
      cache[:c] = 3

      expect(cache.to_h)
        .to be_instance_of(Hash)
        .and be_compare_by_identity
        .and eq(
          {a: 1, b: 2, c: 3}.compare_by_identity
        )
    end

    context "with block" do
      before do
        cache[:a] = 1
        cache[:b] = 2
      end

      it "converts [key, value] pairs returned by the block to a hash" do
        expect(cache.to_h { |k, v| [k.upcase, v * v] })
          .to eq({A: 1, B: 4}.compare_by_identity)
      end
    end
  end

  describe "#write" do
    it "associates the key with the value and return the value" do
      cache.write(:a, 1)
      expect(cache.write(:b, 2)).to eq 2

      expect(cache.to_h).to eq({a: 1, b: 2}.compare_by_identity)
    end

    it "is aliased to #[]=" do
      expect(cache.method(:[]=)).to eq cache.method(:write)

      cache[:a] = 1
      expect(cache[:b] = 2).to eq 2
      expect(cache.send(:[]=, :c, 3)).to eq 3

      expect(cache.to_h).to eq({a: 1, b: 2, c: 3}.compare_by_identity)
    end
  end
end
