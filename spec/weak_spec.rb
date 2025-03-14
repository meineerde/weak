# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require "spec_helper"

RSpec.describe Weak do
  describe "UNDEFINED" do
    it "defines the UndefinedClass" do
      expect(Weak::UndefinedClass).to be_a Class

      # No (further) objects can be created of this class
      expect { Weak::UndefinedClass.new }.to raise_error NoMethodError
      expect { Weak::UndefinedClass.allocate }.to raise_error NoMethodError
    end

    it "defines the singleton object" do
      expect(Weak::UNDEFINED).to be_instance_of Weak::UndefinedClass
      expect(Weak::UNDEFINED.to_s)
        .to eq("UNDEFINED")
        .and be_frozen

      expect(Weak::UNDEFINED)
        .to not_eq(nil)
        .and not_eq(false)
        .and not_eq(true)
        .and not_eq(42)
        .and not_eq("UNDEFINED")
    end

    it "can't be cloned" do
      expect { Weak::UNDEFINED.clone }.to raise_error TypeError
    end

    it "can't be duped" do
      expect { Weak::UNDEFINED.dup }.to raise_error TypeError
    end
  end
end
