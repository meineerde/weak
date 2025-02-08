# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require "bundler/inline"
gemfile(true) do
  source "https://rubygems.org"
  gem "benchmark-ips"
end

weak_map = ObjectSpace::WeakMap.new
hash = {}
identity_hash = {}.compare_by_identity

1000.times do |i|
  s = i.to_s

  weak_map[s] = s
  hash[s] = s
  identity_hash[s] = s
end

Benchmark.ips do |x|
  x.report("WeakMap#values") { weak_map.values }
  x.report("Hash#values") { hash.values }
  x.report("Hash(id)#values") { identity_hash.values }

  x.report("WeakMap#each_value") { weak_map.each_value { |s| s } }
  x.report("Hash#each_value") { hash.each_value { |s| s } }
  x.report("Hash(id)#each_value") { identity_hash.each_value { |s| s } }

  x.compare!
end
