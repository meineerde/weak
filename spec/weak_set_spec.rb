# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require "spec_helper"

require "pp"
require "set"

RSpec.describe WeakSet do
  let(:set) { WeakSet.new }

  it "is an Enumerable" do
    expect(WeakSet).to be < ::Enumerable
    expect(::Enumerable.public_instance_methods - set.methods)
      .to be_empty
  end

  it "implements most Set methods" do
    expected_methods = Set.new.methods.sort - [
      # A WeakSet is generally not used to store strings to be combined.
      :join,

      # A weak set is unsuitable for these operations as the mopdified elements
      # objects would be quickly garbage collected.
      :map!,
      :collect!,
      :classify,
      :divide,
      :flatten,
      :flatten!,
      :flatten_merge,

      # These methods are not used by us and should have been private in the Set
      # class in the first place anyway.
      :initialize_clone,
      :initialize_dup,

      # We always use the object identity of elements. There is no need to
      # rehash / reset the storage.
      :reset
    ]
    common_methods = (expected_methods & set.methods)
    expect(common_methods).to match expected_methods
  end

  describe ".[]" do
    it "returns a WeakSet" do
      expect(WeakSet[1, 2, 3])
        .to be_a(WeakSet)
        .and contain_exactly(1, 2, 3)
    end

    it "does not flatten arguments" do
      expect(WeakSet[].size).to eq 0
      expect(WeakSet[nil].size).to eq 1
      expect(WeakSet[[]].size).to eq 1
      expect(WeakSet[[nil]].size).to eq 1
    end

    it "ignores duplicate values" do
      expect(WeakSet[2, 4, 6, 4]).to eq WeakSet[2, 4, 6]
    end
  end

  describe "#initialize" do
    it "creates an empty set" do
      expect(WeakSet.new).to be_a(WeakSet).and be_empty
    end

    it "ignores nil" do
      expect(WeakSet.new(nil)).to be_a(WeakSet).and be_empty
    end

    it "merges an enum" do
      expect(WeakSet.new([])).to be_a(WeakSet).and be_empty

      expect(WeakSet.new([1, 2])).to be_a(WeakSet).and be_any
      expect(WeakSet.new("a".."c")).to be_a(WeakSet).and be_any
    end

    it "raises ArgumentError on invalid arguments" do
      expect { WeakSet.new(false) }.to raise_error(ArgumentError)
      expect { WeakSet.new(1) }.to raise_error(ArgumentError)
      expect { WeakSet.new(1, 2) }.to raise_error(ArgumentError)
    end

    it "does not change the argument" do
      ary = [2, 4, 6, 4]
      ary_hash = ary.hash
      set = WeakSet.new(ary)

      expect(ary.hash).to eq ary_hash
      ary.clear

      expect(set).not_to be_empty
      expect(set.size).to eq 3
    end

    it "accepts a block to modify the enum's arguments" do
      ary = [1, 2, 3]

      expect(WeakSet.new(ary) { |i| i * 2 })
        .to be_a(WeakSet)
        .and contain_exactly(2, 4, 6)
    end

    it "ignores a block without an argument" do
      expect { |b| WeakSet.new(&b) }.not_to yield_control
    end
  end

  describe "#|" do
    let(:set) { WeakSet[:foo] }

    it "returns the addition of elements" do
      expect(set | WeakSet[:bar])
        .to be_a(WeakSet)
        .and not_equal(set)
        .and contain_exactly(:foo, :bar)
    end

    it "keeps existing values" do
      expect(set | WeakSet[:foo, :bar]).to contain_exactly(:foo, :bar)
    end

    it "allows to use an Array" do
      expect(set | [:bar])
        .to be_a(WeakSet)
        .and not_equal(set)
        .and contain_exactly(:foo, :bar)
    end

    it "allows to use an object which responds only to #each" do
      expect(set | enumerable_mock([:bar], :each))
        .to be_a(WeakSet)
        .and not_equal(set)
        .and contain_exactly(:foo, :bar)
    end

    it "allows to use an object which responds only to #each_entry" do
      expect(set | enumerable_mock([:bar], :each_entry))
        .to be_a(WeakSet)
        .and not_equal(set)
        .and contain_exactly(:foo, :bar)
    end

    it "raises ArgumentError on invalid arguments" do
      expect { set | :foo }.to raise_error(ArgumentError)
      expect { set | 123 }.to raise_error(ArgumentError)
      expect { set | nil }.to raise_error(ArgumentError)
      expect { set | true }.to raise_error(ArgumentError)
    end

    it "is aliased to #+" do
      expect(set.method(:+)).to eq set.method(:|)
      expect(set + WeakSet[:foo, :bar]).to contain_exactly(:foo, :bar)
    end

    it "is aliased to #union" do
      expect(set.method(:union)).to eq set.method(:|)
      expect(set.union(WeakSet[:foo, :bar])).to contain_exactly(:foo, :bar)
    end
  end

  describe "&" do
    let(:set) { WeakSet[:foo, :bar] }

    it "returns the intersection of elements" do
      expect(set & WeakSet[:bar, :boing])
        .to be_a(WeakSet)
        .and not_equal(set)
        .and contain_exactly(:bar)
    end

    it "allows to use an Array" do
      expect(set & [:bar, :boing])
        .to be_a(WeakSet)
        .and not_equal(set)
        .and contain_exactly(:bar)
    end

    it "allows to use an object which responds only to #each" do
      expect(set & enumerable_mock([:bar, :boing], :each))
        .to be_a(WeakSet)
        .and not_equal(set)
        .and contain_exactly(:bar)
    end

    it "allows to use an object which responds only to #each_entry" do
      expect(set & enumerable_mock([:bar, :boing], :each_entry))
        .to be_a(WeakSet)
        .and not_equal(set)
        .and contain_exactly(:bar)
    end

    it "raises ArgumentError on invalid arguments" do
      expect { set & :foo }.to raise_error(ArgumentError)
      expect { set & 123 }.to raise_error(ArgumentError)
      expect { set & nil }.to raise_error(ArgumentError)
      expect { set & true }.to raise_error(ArgumentError)
    end

    it "is aliased to #intersection" do
      expect(set.method(:intersection)).to eq set.method(:&)
      expect(set.intersection(WeakSet[:foo, :boing])).to contain_exactly(:foo)
    end
  end

  describe "#-" do
    before do
      set << :foo << :bar
    end

    it "returns the subtraction of elements" do
      expect(set - WeakSet[:foo])
        .to be_a(WeakSet)
        .and not_equal(set)
        .and contain_exactly(:bar)

      expect(set).to contain_exactly(:foo, :bar)
    end

    it "ignores non-existing values" do
      expect(set - WeakSet[:bar, :baz])
        .to be_a(WeakSet)
        .and not_equal(set)
        .and contain_exactly(:foo)

      expect(set).to contain_exactly(:foo, :bar)
    end

    it "allows to use an Array" do
      expect(set - [:foo])
        .to be_a(WeakSet)
        .and not_equal(set)
        .and contain_exactly(:bar)
    end

    it "allows to use an object which responds only to #each" do
      expect(set - enumerable_mock([:foo], :each))
        .to be_a(WeakSet)
        .and not_equal(set)
        .and contain_exactly(:bar)
    end

    it "allows to use an object which responds only to #each_entry" do
      expect(set - enumerable_mock([:foo], :each_entry))
        .to be_a(WeakSet)
        .and not_equal(set)
        .and contain_exactly(:bar)
    end

    it "raises ArgumentError on invalid arguments" do
      expect { set - :foo }.to raise_error(ArgumentError)
      expect { set - 123 }.to raise_error(ArgumentError)
      expect { set - nil }.to raise_error(ArgumentError)
      expect { set - true }.to raise_error(ArgumentError)
    end

    it "is aliased to #difference" do
      expect(set.method(:difference)).to eq set.method(:-)
      expect(set.difference(WeakSet[:foo])).to contain_exactly(:bar)
    end
  end

  describe "#<=>" do
    before do
      set.merge [1, 2, 3]
    end

    it "returns nil for invalid comparisons" do
      expect(set <=> 2).to be_nil
      expect(set <=> nil).to be_nil
      expect(set <=> true).to be_nil

      expect(set <=> set.to_a).to be_nil
    end

    it "checks for proper superset / subset" do
      expect(set <=> WeakSet[1, 2, 3, 4]).to eq(-1)
      expect(set <=> WeakSet[3, 2, 1]).to eq 0
      expect(set <=> WeakSet[2, 3]).to eq 1
      expect(set <=> WeakSet[]).to eq 1

      expect(WeakSet.new <=> WeakSet.new).to eq 0
    end

    it "returns nil when proper subset / sueprset" do
      # overlapping, but not a proper subset / superset
      expect(set <=> WeakSet[1, 2, 4]).to be_nil

      # no overlap
      expect(set <=> WeakSet[4, :foo]).to be_nil
    end
  end

  describe "#==" do
    it "compares sets" do
      set1 = WeakSet[2, 3, 1]
      set2 = WeakSet[1, 2, 3]

      expect(set1).to eq set1
      expect(set1).to eq set2
      expect(WeakSet[1]).not_to eq [1]
    end

    it "compares recursive sets" do
      set.merge [:a, :b]
      set << set
      expect(set).to eq set
    end

    it "checks objects by their identity" do
      s1 = +"string"
      s2 = +"string"
      expect(s1).not_to equal(s2)

      set1 = WeakSet[s1]
      set2 = WeakSet[s2]
      expect(set1).not_to eq set2
    end

    it "requires the same numebr of elements" do
      set << :foo
      expect(WeakSet[]).not_to eq set
      expect(set).not_to eq WeakSet[]
    end
  end

  describe "#^" do
    it "performs an xor" do
      set = WeakSet[1, 2, 3, 4]
      other = WeakSet[2, 4, 5, 5]

      expect(set ^ other)
        .to be_a(WeakSet)
        .and not_equal(set)
        .and not_equal(other)
        .and contain_exactly(1, 3, 5)

      # The original objects are not changed.
      expect(set).to contain_exactly(1, 2, 3, 4)
      expect(other).to contain_exactly(2, 4, 5)
    end

    it "checks objects by their identity" do
      s1 = +"string"
      s2 = +"string"
      expect(s1).not_to equal(s2)

      expect((WeakSet[:foo, s1] ^ WeakSet[s2, :foo]).map(&:object_id))
        .to contain_exactly(s1.object_id, s2.object_id)
    end

    it "accepts an Enumerable" do
      set = WeakSet[1, 2, 3, 4]
      other = [2, 4, 5, 5]

      expect(set ^ other)
        .to be_a(WeakSet)
        .and contain_exactly(1, 3, 5)

      # The original objects are not changed.
      expect(set).to contain_exactly(1, 2, 3, 4)
      expect(other).to eq [2, 4, 5, 5]
    end

    it "raises AgumentError on invalid arguments" do
      expect { set ^ :foo }.to raise_error(ArgumentError)
      expect { set ^ 123 }.to raise_error(ArgumentError)
      expect { set ^ nil }.to raise_error(ArgumentError)
      expect { set ^ true }.to raise_error(ArgumentError)
    end
  end

  describe "#[]" do
    before do
      set << :foo
    end

    it "returns the object if it is in the set" do
      expect(set[:foo]).to eq :foo

      string = +"foo"
      set << string
      expect(set[string]).to equal string
    end

    it "returns nil if the object is not in the set" do
      expect(set[nil]).to be_nil

      expect(set[123]).to be_nil
      expect(set["foo"]).to be_nil
      expect(set[true]).to be_nil
    end

    it "does not return deleted objects" do
      expect(set[:foo]).to eq :foo
      set.delete(:foo)
      expect(set[:foo]).to be_nil
    end
  end

  describe "#add" do
    let(:set) { WeakSet[1, 2, 3] }

    it "adds an object" do
      expect { set.add(5) }.to change(set, :size).from(3).to(4)
      expect(set).to contain_exactly(1, 2, 3, 5)
    end

    it "ignores existing objects" do
      expect { set.add(2) }.not_to change(set, :size)
      expect(set).to contain_exactly(1, 2, 3)
    end

    it "returns the set" do
      expect(set.add(2)).to equal set
      expect(set.add(5)).to equal set
    end

    it "is aliased to :<<" do
      # This is ore "manual" because Ruby 3.4 distinguishes the method owner,
      # i.e., the module where the method or alias was defined. In previous
      # Ruby versions, that didn't matter.
      expect(set.method(:<<)).to have_attributes(
        owner: WeakSet,
        source_location: set.method(:add).source_location
      )

      expect { set << :foo }.to change(set, :length).from(3).to(4)
      expect(set).to contain_exactly(1, 2, 3, :foo)
    end
  end

  describe "#add?" do
    let(:set) { WeakSet[1, 2, 3] }

    it "adds an object" do
      expect { set.add?(5) }.to change(set, :size).from(3).to(4)
      expect(set).to contain_exactly(1, 2, 3, 5)
    end

    it "ignores existing objects" do
      expect { set.add?(2) }.not_to change(set, :size)
      expect(set).to contain_exactly(1, 2, 3)
    end

    it "returns the set if the object was added" do
      expect(set.add?(5)).to equal set
    end

    it "returns nil if the object was already in the set" do
      expect(set.add?(2)).to be_nil
    end

    it "considers object identity" do
      s1 = +"string"
      s2 = +"string"
      expect(s1).not_to equal s2

      set.add s1
      expect(set.add?(s2)).to equal set
      expect(set.to_a.map(&:object_id)).to include(s1.object_id, s2.object_id)
    end
  end

  describe "#clear" do
    it "clears the set" do
      set.merge [1, 2]

      expect(set.clear)
        .to equal(set)
        .and be_empty
    end

    it "cleans up internal data" do
      # This is only relevant for WeakSet::StrongSecondaryKeys
      key_map = set.instance_variable_get(:@key_map)
      if key_map
        set.merge [1, 2]
        expect(key_map).not_to be_empty

        set.clear
        expect(key_map).to be_empty
      end
    end
  end

  describe "#clone" do
    before do
      set << :foo
    end

    it "clones the set" do
      expect(set.clone)
        .to be_a(WeakSet)
        .and not_equal(set)
        .and contain_exactly(:foo)

      clone = set.clone
      set << :bar
      clone << :boing

      expect(set).to contain_exactly(:foo, :bar)
      expect(clone).to contain_exactly(:foo, :boing)
    end

    it "allows to use freeze: false" do
      expect(set.clone(freeze: false))
        .to be_a(WeakSet)
        .and not_equal(set)
        .and contain_exactly(:foo)
        .and not_be_frozen
    end

    it "ignores freeze: true" do
      allow(set).to receive(:warn)

      expect(set.clone(freeze: true))
        .to be_a(WeakSet)
        .and not_equal(set)
        .and contain_exactly(:foo)
        .and not_be_frozen
      expect(set).to have_received(:warn).with("Can't freeze WeakSet")

      # Instance variables of the clone set won't be frozen either
      expect(set.clone(freeze: true).instance_variables).to all satisfy { |v|
        !set.instance_variable_get(v).frozen?
      }
    end
  end

  describe "#compare_by_identity" do
    it "returns self" do
      expect(set.compare_by_identity).to equal set
    end
  end

  describe "#compare_by_identity?" do
    it "always returns true" do
      expect(set.compare_by_identity?).to be true
      set.compare_by_identity
      expect(set.compare_by_identity?).to be true
    end
  end

  describe "#delete" do
    let(:set) { WeakSet[1, 2, 3] }

    it "deletes an object" do
      expect(set.delete(3)).to equal(set)
      expect(set.include?(3)).to be false
      expect(set).to contain_exactly(1, 2)
    end

    it "ignores missing objects" do
      expect(set.delete(4)).to equal(set)
      expect(set.include?(4)).to be false
      expect(set).to contain_exactly(1, 2, 3)
    end
  end

  describe "#delete?" do
    let(:set) { WeakSet[1, 2, 3] }

    it "deletes an object" do
      expect { set.delete?(2) }.to change(set, :size).from(3).to(2)
      expect(set).to contain_exactly(1, 3)
    end

    it "ignores missing objects" do
      expect { set.delete?(5) }.not_to change(set, :size)
      expect(set).to contain_exactly(1, 2, 3)
    end

    it "returns the set if the object was deleted, nil otherwise" do
      expect(set.delete?(2)).to equal set
      expect(set.delete?(2)).to be_nil

      set.add nil
      expect(set.delete?(nil)).to equal set
      expect(set.delete?(nil)).to be_nil

      set.add false
      expect(set.delete?(false)).to equal set
      expect(set.delete?(false)).to be_nil
    end

    it "returns nil if the object was not in the set" do
      expect(set.delete?(5)).to be_nil
      expect(set.delete?(nil)).to be_nil
      expect(set.delete?(false)).to be_nil
    end

    it "considers object identity" do
      s1 = +"string"
      s2 = +"string"
      expect(s1).not_to equal s2

      set.add s1
      expect(set.delete?(s2)).to be_nil
      expect(set.delete?(s1)).to equal(set)

      expect(set).to contain_exactly(1, 2, 3)
    end

    it "cleans up object references after garbage collection" do
      collectable do
        set << (string = +"foo")
        expect(set).to include(string)
        expect(set.instance_variable_get(:@map).size).to eq 4
      end

      garbage_collect_until do
        expect(set.instance_variable_get(:@map).size).to eq 3
      end
    end
  end

  describe "#delete_if" do
    let(:set) { WeakSet.new(1..10) }

    it "deletes element for which the block matches" do
      expect(set.delete_if { |i| i % 3 == 0 })
        .to equal(set)
        .and contain_exactly(1, 2, 4, 5, 7, 8, 10)
    end

    it "deletes nothing if the block never matches" do
      expect(set.delete_if { |i| i > 10 })
        .to equal(set)
        .and contain_exactly(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
    end

    it "returns a sized Enumerator without a block" do
      enumerator = set.delete_if

      expect(set.delete_if)
        .to be_a(Enumerator)
        .and have_attributes(size: set.size)

      expect(enumerator.each { |i| i % 3 == 0 })
        .to equal(set)
        .and contain_exactly(1, 2, 4, 5, 7, 8, 10)
    end
  end

  describe "#disjoint?" do
    let(:set) { WeakSet[3, 4, 5] }

    it "rejects the same set" do
      expect(set.disjoint?(set)).to be false
      expect(set.disjoint?(set.to_a)).to be false
    end

    it "rejects intersecting sets" do
      expect(set.disjoint?(WeakSet[2, 4, 6])).to be false
      expect(set.disjoint?([2, 4, 6])).to be false
      expect(WeakSet[2, 4, 6].disjoint?(set)).to be false

      expect(set.disjoint?(WeakSet[2, 4])).to be false
      expect(set.disjoint?([2, 4])).to be false
      expect(WeakSet[2, 4].disjoint?(set)).to be false

      expect(set.disjoint?(WeakSet[5, 6, 7])).to be false
      expect(set.disjoint?([5, 6, 7])).to be false
      expect(WeakSet[5, 6, 7].disjoint?(set)).to be false

      expect(set.disjoint?(WeakSet[1, 2, 6, 8, 4])).to be false
      expect(set.disjoint?([1, 2, 6, 8, 4])).to be false
      expect(WeakSet[1, 2, 6, 8, 4].disjoint?(set)).to be false

      # Make sure set hasn't changed
      expect(set).to eq WeakSet[3, 4, 5]
    end

    it "accepts disjoint sets" do
      expect(set.disjoint?(WeakSet[])).to be true
      expect(set.disjoint?([])).to be true
      expect(WeakSet[].disjoint?(set)).to be true

      expect(set.disjoint?(WeakSet[0, 2])).to be true
      expect(set.disjoint?([0, 2])).to be true
      expect(WeakSet[0, 2].disjoint?(set)).to be true

      expect(set.disjoint?(WeakSet[0, 2, 6])).to be true
      expect(set.disjoint?([0, 2, 6])).to be true
      expect(WeakSet[0, 2, 6].disjoint?(set)).to be true

      expect(set.disjoint?(WeakSet[0, 2, 6, 8, 10])).to be true
      expect(set.disjoint?([0, 2, 6, 8, 10])).to be true
      expect(WeakSet[0, 2, 6, 8, 10].disjoint?(set)).to be true

      # Make sure set hasn't changed
      expect(set).to eq WeakSet[3, 4, 5]
    end

    it "accepts any Enumerable" do
      expect(set.disjoint?([7])).to be true
      expect(set.disjoint?(Set[7])).to be true
      expect(set.disjoint?(enumerable_mock([7], :each))).to be true
      expect(set.disjoint?(enumerable_mock([7], :each_entry))).to be true
    end

    it "raises ArgumentError on invalid arguments" do
      expect { set.disjoint? 3 }.to raise_error ArgumentError
      expect { set.disjoint? nil }.to raise_error ArgumentError
      expect { set.disjoint? :foo }.to raise_error ArgumentError
    end
  end

  describe "#dup" do
    before do
      set << :foo
    end

    it "duplicates the set" do
      expect(set.dup)
        .to be_a(WeakSet)
        .and not_equal(set)
        .and contain_exactly(:foo)

      dup = set.dup
      set << :bar
      dup << :boing
      expect(set).to contain_exactly(:foo, :bar)
      expect(dup).to contain_exactly(:foo, :boing)
    end
  end

  describe "#each" do
    let(:set) { WeakSet[1, 3, 5, 7, 10, 20] }

    it "returns self" do
      expect(set.each {}).to equal set
    end

    it "yields each element" do
      expect { |b| set.each(&b) }.to yield_successive_args(*([Integer] * 6))
    end

    it "returns an Enumerator without a block" do
      enumerator = set.each

      expect(enumerator)
        .to be_a(Enumerator)
        .and have_attributes(size: set.size)

      expect { |b| enumerator.each(&b) }
        .to yield_successive_args(*[Integer] * 6)
    end

    it "allows to modify the set while enumerating" do
      yielded = []
      set.each do |o|
        yielded << o
        set.delete(set.first)
      end

      expect(yielded).to contain_exactly(1, 3, 5, 7, 10, 20)
    end
  end

  describe "#empty?" do
    it "returns false for a populated set" do
      expect(WeakSet[1, 2].empty?).to be false
    end

    it "returns true for an empty set" do
      expect(WeakSet[].empty?).to be true
    end

    it "returns true as elements are garbage collected" do
      collectable do
        set << string = +"foo"
        expect(set).to include(string)
      end

      garbage_collect_until do
        expect(set.empty?).to be true
      end
    end
  end

  describe "#freeze" do
    before do
      allow(set).to receive(:warn)
    end

    it "returns self" do
      expect(set.freeze).to equal(set)
    end

    it "does not actually freeze" do
      set.freeze

      expect(set).not_to be_frozen
      expect(set.instance_variables).to all satisfy { |v|
        !set.instance_variable_get(v).frozen?
      }
    end

    it "warns that we can not freeze a WeakSet" do
      set.freeze
      expect(set).to have_received(:warn).with("Can't freeze WeakSet")
    end
  end

  describe "#include?" do
    it "checks inclusion" do
      set.merge [1, 2, 3]
      expect(set.include?(1)).to be true
      expect(set.include?(2)).to be true
      expect(set.include?(3)).to be true

      expect(set.include?(0)).to be false
      expect(set.include?(nil)).to be false

      set = WeakSet[:a, nil, :b, nil, :c, :d, false]
      expect(set.include?(nil)).to be true
      expect(set.include?(false)).to be true
      expect(set.include?(:a)).to be true
      expect(set.include?(0)).to be false
      expect(set.include?(true)).to be false
    end

    it "considers object identity" do
      string1 = +"string"
      string2 = +"string"
      expect(string1).not_to equal string2

      set << string1
      expect(set.include?(string1)).to be true
      expect(set.include?(string2)).to be false
    end

    it "garbage collects @key_map for WeakSet::StrongSecondaryKeys" do
      if weak_module.name == "WeakSet::StrongSecondaryKeys"
        collectable do
          numbers = (1..5000).map(&:to_s)
          numbers.each do |n|
            set << n
          end
          expect(set.instance_variable_get(:@map).size).to eq 5000
          expect(set.instance_variable_get(:@key_map).size).to eq 5000
        end

        # The out-ouf-scope strings will be garbage collected removed from the
        # @map
        garbage_collect_until do
          expect(set.instance_variable_get(:@map).size).to eq 0
        end
        expect(set.instance_variable_get(:@key_map).size).to eq 5000

        # The include? call runs the garbage collection for the key_map here
        expect(set.include?(123)).to be false
        expect(set.instance_variable_get(:@key_map).size).to eq 0
      end
    end

    it "is aliased to #===" do
      # This is ore "manual" because Ruby 3.4 distinguishes the method owner,
      # i.e., the module where the method or alias was defined. In previous
      # Ruby versions, that didn't matter.
      expect(set.method(:===)).to have_attributes(
        owner: WeakSet,
        source_location: set.method(:include?).source_location
      )

      set << :foo
      expect(set === :foo).to be true
      expect(set === :bar).to be false
    end

    it "is aliased to #member?" do
      # This is ore "manual" because Ruby 3.4 distinguishes the method owner,
      # i.e., the module where the method or alias was defined. In previous
      # Ruby versions, that didn't matter.
      expect(set.method(:member?)).to have_attributes(
        owner: WeakSet,
        source_location: set.method(:include?).source_location
      )

      set << :foo
      expect(set.member?(:foo)).to be true
      expect(set.member?(:bar)).to be false
    end
  end

  describe "#inspect" do
    let(:set) { WeakSet[1, 2] }
    let(:set2) { WeakSet[WeakSet[0], 1, 2, set] }

    it "shows details" do
      expect(set.inspect).to eq "#<WeakSet: {1, 2}>"
    end

    it "inspects nested sets" do
      expect(set2.inspect).to eq "#<WeakSet: {1, 2, #<WeakSet: {0}>, #<WeakSet: {1, 2}>}>"
    end

    it "handles infinite recursion" do
      set.add(set2)
      expect(set2.inspect)
        .to eq "#<WeakSet: {1, 2, #<WeakSet: {0}>, #<WeakSet: {1, 2, #<WeakSet: {...}>}>}>"
    end

    it "is aliased to #to_s" do
      expect(set.method(:to_s)).to eq set.method(:inspect)
      expect(set.to_s).to eq "#<WeakSet: {1, 2}>"
    end

    it "does not swallow nested exceptions" do
      errored = Class.new do
        def inspect
          raise("Oh Noes!")
        end
      end.new
      set << errored

      expect { set.inspect }.to raise_error(RuntimeError, "Oh Noes!")
    end
  end

  describe "#intersect?" do
    let(:set) { WeakSet[3, 4, 5] }

    it "accepts the same set" do
      expect(set.intersect?(set)).to be true
      expect(set.intersect?(set.to_a)).to be true
    end

    it "accepts intersecting sets" do
      expect(set.intersect?(WeakSet[2, 4, 6])).to be true
      expect(set.intersect?([2, 4, 6])).to be true
      expect(WeakSet[2, 4, 6].intersect?(set)).to be true

      expect(set.intersect?(WeakSet[2, 4])).to be true
      expect(set.intersect?([2, 4])).to be true
      expect(WeakSet[2, 4].intersect?(set)).to be true

      expect(set.intersect?(WeakSet[5, 6, 7])).to be true
      expect(set.intersect?([5, 6, 7])).to be true
      expect(WeakSet[5, 6, 7].intersect?(set)).to be true

      expect(set.intersect?(WeakSet[1, 2, 6, 8, 4])).to be true
      expect(set.intersect?([1, 2, 6, 8, 4])).to be true
      expect(WeakSet[1, 2, 6, 8, 4].intersect?(set)).to be true

      # Make sure set hasn't changed
      expect(set).to eq WeakSet[3, 4, 5]
    end

    it "rejects disjoint sets" do
      expect(set.intersect?(WeakSet[])).to be false
      expect(set.intersect?([])).to be false
      expect(WeakSet[].intersect?(set)).to be false

      expect(set.intersect?(WeakSet[0, 2])).to be false
      expect(set.intersect?([0, 2])).to be false
      expect(WeakSet[0, 2].intersect?(set)).to be false

      expect(set.intersect?(WeakSet[0, 2, 6])).to be false
      expect(set.intersect?([0, 2, 6])).to be false
      expect(WeakSet[0, 2, 6].intersect?(set)).to be false

      expect(set.intersect?(WeakSet[0, 2, 6, 8, 10])).to be false
      expect(set.intersect?([0, 2, 6, 8, 10])).to be false
      expect(WeakSet[0, 2, 6, 8, 10].intersect?(set)).to be false

      # Make sure set hasn't changed
      expect(set).to eq WeakSet[3, 4, 5]
    end

    it "accepts any Enumerable" do
      expect(set.intersect?([3])).to be true
      expect(set.intersect?(Set[3])).to be true
      expect(set.intersect?(enumerable_mock([3], :each))).to be true
      expect(set.intersect?(enumerable_mock([3], :each_entry))).to be true
    end

    it "raises ArgumentError on invalid arguments" do
      expect { set.intersect? 3 }.to raise_error ArgumentError
      expect { set.intersect? nil }.to raise_error ArgumentError
      expect { set.intersect? :foo }.to raise_error ArgumentError
    end
  end

  describe "#keep_if" do
    let(:set) { WeakSet.new(1..10) }

    it "keeps all elements for which the block matches" do
      expect(set.keep_if { |i| i <= 10 })
        .to equal(set)
        .and contain_exactly(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
    end

    it "deletes averything if the block never matches" do
      expect(set.keep_if { |i| i > 10 })
        .to equal(set)
        .and be_empty
    end

    it "deletes element for which the block does not match" do
      expect(set.keep_if { |i| i % 3 == 0 })
        .to equal(set)
        .and contain_exactly(3, 6, 9)
    end

    it "returns a sized Enumerator without a block" do
      enumerator = set.keep_if

      expect(enumerator)
        .to be_a(Enumerator)
        .and have_attributes(size: set.size)

      expect(enumerator.each { |i| i % 3 == 0 })
        .to equal(set)
        .and contain_exactly(3, 6, 9)
    end
  end

  describe "#pretty_print" do
    let(:set) { WeakSet[1, 2, 3] }

    it "pretty prints wide" do
      expect(set).to receive(:pretty_print).with(PP).and_call_original
      expect(PP.pp(set, +"", 80)).to eq "#<WeakSet: {1, 2, 3}>\n"
    end

    it "pretty prints medium wide" do
      expect(set).to receive(:pretty_print).with(PP).and_call_original
      expect(PP.pp(set, +"", 12)).to eq <<~PP
        #<WeakSet:
         {1, 2, 3}>
      PP
    end

    it "pretty prints narrow" do
      expect(set).to receive(:pretty_print).with(PP).and_call_original
      expect(PP.pp(set, +"", 2)).to eq <<~PP
        #<WeakSet:
         {1,
          2,
          3}>
      PP
    end
  end

  describe "#pretty_print_cycle" do
    let(:set) {
      set = WeakSet[1, 2, 3]
      set << set
    }

    it "pretty prints nested sets" do
      expect(set).to receive(:pretty_print_cycle).with(PP).and_call_original
      expect(PP.pp(set, +"", 12)).to eq <<~PP
        #<WeakSet:
         {1,
          2,
          3,
          #<WeakSet: {...}>}>
      PP
    end
  end

  describe "#proper_subset?" do
    let(:set) { WeakSet[1, 2, 3] }

    it "compares sets" do
      expect(set.proper_subset?(WeakSet[1, 2, 3])).to be false
      expect(set.proper_subset?(WeakSet[1, 2, 3, 4])).to be true
      expect(set.proper_subset?(WeakSet[1, 2])).to be false

      expect(set.proper_subset?(WeakSet[1, 2, 5])).to be false
      expect(set.proper_subset?(WeakSet[:foo, :bar, :baz])).to be false

      expect(WeakSet[].proper_subset?(WeakSet[])).to be false
    end

    it "raises ArgumentError on invalid arguments" do
      expect { set.proper_subset? }.to raise_error(ArgumentError)
      expect { set.proper_subset?(2) }.to raise_error(ArgumentError)
      expect { set.proper_subset?([2]) }.to raise_error(ArgumentError)
    end

    it "is aliased to #<" do
      expect(set.method(:<)).to eq set.method(:proper_subset?)

      expect(set < WeakSet[1, 2, 3]).to be false
      expect(set < WeakSet[1, 2, 3, 4]).to be true
      expect(set < WeakSet[1, 2]).to be false
      expect(set < WeakSet[1, 2, 5]).to be false
    end
  end

  describe "#proper_superset?" do
    let(:set) { WeakSet[1, 2, 3] }

    it "compares sets" do
      expect(set.proper_superset?(WeakSet[1, 2, 3])).to be false
      expect(set.proper_superset?(WeakSet[1, 2])).to be true
      expect(set.proper_superset?(WeakSet[1, 2, 3, 4])).to be false

      expect(set.proper_superset?(WeakSet[1, 2, 5])).to be false
      expect(set.proper_superset?(WeakSet[:foo, :bar, :baz])).to be false

      expect(WeakSet[].proper_superset?(WeakSet[])).to be false
    end

    it "raises ArgumentError on invalid arguments" do
      expect { set.proper_superset? }.to raise_error(ArgumentError)
      expect { set.proper_superset?(2) }.to raise_error(ArgumentError)
      expect { set.proper_superset?([2]) }.to raise_error(ArgumentError)
    end

    it "is aliased to #>" do
      expect(set.method(:>)).to eq set.method(:proper_superset?)

      expect(set > WeakSet[1, 2, 3]).to be false
      expect(set > WeakSet[1, 2]).to be true
      expect(set > WeakSet[1, 2, 3, 4]).to be false
      expect(set > WeakSet[1, 2, 5]).to be false
    end
  end

  describe "#reject!" do
    let(:set) { WeakSet.new(1..10) }

    it "deletes element for which the block matches" do
      expect(set.reject! { |i| i % 3 == 0 })
        .to equal(set)
        .and contain_exactly(1, 2, 4, 5, 7, 8, 10)
    end

    it "deletes nothing if the block never matches" do
      expect(set.reject! { |i| i > 10 }).to be_nil
      expect(set).to contain_exactly(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
    end

    it "returns a sized Enumerator without a block" do
      enumerator = set.reject!

      expect(set.reject!)
        .to be_a(Enumerator)
        .and have_attributes(size: set.size)

      expect(enumerator.each { |i| i % 3 == 0 })
        .to equal(set)
        .and contain_exactly(1, 2, 4, 5, 7, 8, 10)
    end
  end

  describe "#replace" do
    it "replaces all elements" do
      set.merge [1, 2]
      expect(set.replace(:a..:c))
        .to equal(set)
        .and contain_exactly(:a, :b, :c)
    end

    it "raises AgumentError on invalid arguments" do
      expect { set.replace :foo }.to raise_error(ArgumentError)
      expect { set.replace 123 }.to raise_error(ArgumentError)
      expect { set.replace nil }.to raise_error(ArgumentError)
      expect { set.replace true }.to raise_error(ArgumentError)
    end

    it "keeps existing data if there's an error" do
      set.merge [1, 2]
      expect { set.replace nil }.to raise_error(ArgumentError)
      expect(set).to contain_exactly(1, 2)
    end

    it "cleans up internal data" do
      # This is only relevant for WeakSet::StrongSecondaryKeys
      key_map = set.instance_variable_get(:@key_map)
      if key_map
        set.merge [1, 2]
        expect(key_map.size).to eq 2

        set.replace(WeakSet[:a, :b, :c, :d])

        # the original @key_map is replaced by a new object
        new_key_map = set.instance_variable_get(:@key_map)
        expect(new_key_map).not_to equal key_map
        expect(new_key_map.size).to eq 4
      end
    end
  end

  describe "#select!" do
    let(:set) { WeakSet.new(1..10) }

    it "returns nil if nothing was changed" do
      expect(set.select! { |i| i <= 10 }).to be_nil
      expect(set).to contain_exactly(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
    end

    it "keeps all elements for which the block matches" do
      expect(set.select! { |i| i % 3 != 0 })
        .to equal(set)
        .and contain_exactly(1, 2, 4, 5, 7, 8, 10)
    end

    it "deletes averything if the block never matches" do
      expect(set.select! { |i| i > 10 })
        .to equal(set)
        .and be_empty
    end

    it "returns a sized Enumerator without a block" do
      enumerator = set.select!

      expect(enumerator)
        .to be_a(Enumerator)
        .and have_attributes(size: set.size)

      expect(enumerator.each { |i| i <= 10 }).to be_nil
      expect(set).to contain_exactly(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
    end

    it "is aliased to #filter!" do
      expect(set.method(:filter!)).to eq set.method(:select!)

      expect(set.filter! { |i| i <= 10 }).to be_nil
      expect(set).to contain_exactly(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)

      expect(set.filter! { |i| i % 3 == 0 })
        .to equal(set)
        .and contain_exactly(3, 6, 9)
    end
  end

  describe "#size" do
    it "returns the number of elements in the set" do
      expect(WeakSet[].size).to eq 0
      expect(WeakSet[1, 2].size).to eq 2
      expect(WeakSet[1, 2, 1].size).to eq 2
    end

    it "decreses when deleting elements" do
      set << :foo
      expect { set.delete :foo }.to change(set, :size).from(1).to(0)
    end

    it "decreases after garbage collection" do
      collectable do
        set << (string = +"foo")
        expect(set).to include(string)

        expect(set.size).to eq 1
      end

      garbage_collect_until do
        expect(set.size).to eq 0
      end
    end

    it "is aliased to #length" do
      # This is ore "manual" because Ruby 3.4 distinguishes the method owner,
      # i.e., the module where the method or alias was defined. In previous
      # Ruby versions, that didn't matter.
      expect(set.method(:length)).to have_attributes(
        owner: WeakSet,
        source_location: set.method(:size).source_location
      )

      expect { set << :foo }.to change(set, :length).from(0).to(1)
    end
  end

  describe "#subset?" do
    let(:set) { WeakSet[1, 2, 3] }

    it "compares" do
      expect(set.subset?(WeakSet[1, 2, 3])).to be true
      expect(set.subset?(WeakSet[1, 2, 3, 4])).to be true
      expect(set.subset?(WeakSet[1, 2])).to be false

      expect(set.subset?(WeakSet[1, 2, 5])).to be false
      expect(set.subset?(WeakSet[:foo, :bar, :baz])).to be false

      expect(WeakSet[].subset?(WeakSet[])).to be true
    end

    it "raises ArgumentError on invalid arguments" do
      expect { set.subset? }.to raise_error(ArgumentError)
      expect { set.subset?(2) }.to raise_error(ArgumentError)
      expect { set.subset?([2]) }.to raise_error(ArgumentError)
    end

    it "is aliased to #<=" do
      expect(set.method(:<=)).to eq set.method(:subset?)

      expect(set <= WeakSet[1, 2, 3]).to be true
      expect(set <= WeakSet[1, 2, 3, 4]).to be true
      expect(set <= WeakSet[1, 2]).to be false
      expect(set <= WeakSet[1, 2, 5]).to be false
    end
  end

  describe "#subtract" do
    let(:set) { WeakSet[1, 2, 3] }

    it "removes elements" do
      expect(set.subtract([2, 4, 6]))
        .to equal(set)
        .and contain_exactly(1, 3)
    end

    it "raises ArgumentError on invalid arguments" do
      expect { set.subtract 1 }.to raise_error(ArgumentError)
      expect { set.subtract nil }.to raise_error(ArgumentError)
      expect { set.subtract :foo }.to raise_error(ArgumentError)
      expect { set.subtract true }.to raise_error(ArgumentError)
    end
  end

  describe "#superset?" do
    let(:set) { WeakSet[1, 2, 3] }

    it "compares" do
      expect(set.superset?(WeakSet[1, 2, 3])).to be true
      expect(set.superset?(WeakSet[1, 2])).to be true
      expect(set.superset?(WeakSet[1, 2, 3, 4])).to be false

      expect(set.superset?(WeakSet[1, 2, 5])).to be false
      expect(set.superset?(WeakSet[:foo, :bar, :baz])).to be false

      expect(WeakSet[].superset?(WeakSet[])).to be true
    end

    it "raises ArgumentError on invalid arguments" do
      expect { set.superset? }.to raise_error(ArgumentError)
      expect { set.superset?(2) }.to raise_error(ArgumentError)
      expect { set.superset?([2]) }.to raise_error(ArgumentError)
    end

    it "is aliased to #>=" do
      expect(set.method(:>=)).to eq set.method(:superset?)

      expect(set >= WeakSet[1, 2, 3]).to be true
      expect(set >= WeakSet[1, 2]).to be true
      expect(set >= WeakSet[1, 2, 3, 4]).to be false
      expect(set >= WeakSet[1, 2, 5]).to be false
    end
  end

  describe "#to_a" do
    it "returns an Array of elements" do
      set = WeakSet[1, 2, 3, 2]
      expect(set.to_a)
        .to be_instance_of(Array)
        .and contain_exactly(1, 2, 3)
    end

    it "skips deleted entries" do
      set << string = +"foo"
      expect(set.to_a).to include(string)

      set.delete(string)
      expect(set).to be_empty
    end

    it "skips garbage-collected entries" do
      collectable do
        set << (string = +"foo") # standard:disable Lint/UselessAssignment
        expect(set).to include(string)
        expect(set).not_to be_empty
      end

      garbage_collect_until do
        expect(set.to_a).to be_empty
      end
    end
  end

  describe "#to_set" do
    let(:set) { WeakSet[1, 2, 3] }

    it "returns a Set" do
      expect(set.to_set).to be_a(Set).and contain_exactly(1, 2, 3)
    end

    it "returns Set with compare_by_identity" do
      set << s1 = +"string"
      set << s2 = +"string"
      s3 = +"string"

      expect(set.to_set).to be_a(Set).and be_compare_by_identity
      expect(set.to_set.map(&:object_id))
        .to contain_exactly(3, 5, 7, s1.object_id, s2.object_id)
      expect(set.to_set.include?(s3)).to be false
    end
  end
end
