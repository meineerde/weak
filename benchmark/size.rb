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
  x.report("WeakMap#size") { weak_map.size }
  x.report("Hash#size") { hash.size }
  x.report("Hash(id)#size") { identity_hash.size }

  x.compare!
end

# jruby 9.4.0.0 (3.1.0) 2022-11-23 95c0ec159f OpenJDK 64-Bit Server VM 23.0.2 on 23.0.2 +jit [arm64-darwin]
# Warming up --------------------------------------
#         WeakMap#size     1.332M i/100ms
#            Hash#size     1.215M i/100ms
#        Hash(id)#size     1.384M i/100ms
# Calculating -------------------------------------
#         WeakMap#size     58.219M (±24.3%) i/s   (17.18 ns/i) -    239.746M in   5.011846s
#            Hash#size     70.654M (±21.4%) i/s   (14.15 ns/i) -    293.915M in   5.011214s
#        Hash(id)#size     68.759M (±25.9%) i/s   (14.54 ns/i) -    269.811M in   5.008673s
#
# Comparison:
#            Hash#size: 70653666.1 i/s
#        Hash(id)#size: 68759275.6 i/s - same-ish: difference falls within error
#         WeakMap#size: 58218522.0 i/s - same-ish: difference falls within error
