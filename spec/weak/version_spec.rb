# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require "spec_helper"
require "weak/version"

RSpec.describe "Weak::VERSION" do
  it "is a version number" do
    expect(Weak::VERSION)
      .to be_a(String)
      .and be_frozen
      .and match %r{\A\d+(?:\.\d+)+(?:\.[a-z][a-z0-9_]+)?\z}i
  end
end
