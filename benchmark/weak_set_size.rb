# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require "bundler/inline"
gemfile(true) do
  source "https://rubygems.org"
  gem "benchmark-ips"
  gemspec name: "weak", path: File.expand_path("..", __dir__)
end

puts Weak::Set.ancestors.find { |m| m.name.start_with?("Weak::Set::") }

set = Weak::Set.new
ary = []
1000.times do |i|
  s = i.to_s
  set << s
  ary << s
end

Benchmark.ips do |x|
  x.report("Weak::Set#size") { set.size }
  x.report("Weak::Set#to_a#size") { set.to_a.size }

  x.compare!
end

# Weak::Set::StrongSecondaryKeys
# jruby 9.4.0.0 (3.1.0) 2022-11-23 95c0ec159f OpenJDK 64-Bit Server VM 23.0.2 on 23.0.2 +jit [arm64-darwin]
# Warming up --------------------------------------
#         Weak::Set#size     2.360k i/100ms
#    Weak::Set#to_a#size     2.763k i/100ms
# Calculating -------------------------------------
#         Weak::Set#size     24.574k (± 0.7%) i/s   (40.69 μs/i) -    125.080k in   5.090141s
#    Weak::Set#to_a#size     27.518k (± 0.6%) i/s   (36.34 μs/i) -    138.150k in   5.020465s
#
# Comparison:
#    Weak::Set#to_a#size:    27518.4 i/s
#         Weak::Set#size:    24574.3 i/s - 1.12x  slower

# Weak::Set::StrongKeys
# jruby 9.4.11.0 (3.1.4) 2025-01-29 9b107851a3 OpenJDK 64-Bit Server VM 23.0.2 on 23.0.2 +jit [arm64-darwin]
# Warming up --------------------------------------
#         Weak::Set#size     1.773k i/100ms
#    Weak::Set#to_a#size     2.548k i/100ms
# Calculating -------------------------------------
#         Weak::Set#size     22.974k (± 1.4%) i/s   (43.53 μs/i) -    115.245k in   5.017399s
#    Weak::Set#to_a#size     25.793k (± 0.5%) i/s   (38.77 μs/i) -    129.948k in   5.038261s
#
# Comparison:
#    Weak::Set#to_a#size:    25792.8 i/s
#         Weak::Set#size:    22974.1 i/s - 1.12x  slower

# Weak::Set::StrongKeys
# truffleruby 24.1.2, like ruby 3.2.4, Oracle GraalVM Native [arm64-darwin20]
# Warming up --------------------------------------
#         Weak::Set#size     8.008k i/100ms
#    Weak::Set#to_a#size     8.133k i/100ms
# Calculating -------------------------------------
#         Weak::Set#size     74.962k (± 8.0%) i/s   (13.34 μs/i) -    376.376k in   5.081763s
#    Weak::Set#to_a#size     79.607k (± 8.2%) i/s   (12.56 μs/i) -    398.517k in   5.079312s
#
# Comparison:
#    Weak::Set#to_a#size:    79607.2 i/s
#         Weak::Set#size:    74961.5 i/s - same-ish: difference falls within error

# Weak::Set::WeakKeys
# ruby 3.0.7p220 (2024-04-23 revision 724a071175) [arm64-darwin24]
# Warming up --------------------------------------
#         Weak::Set#size     3.117k i/100ms
#    Weak::Set#to_a#size     2.586k i/100ms
# Calculating -------------------------------------
#         Weak::Set#size     31.011k (± 0.7%) i/s   (32.25 μs/i) -    155.850k in   5.025920s
#    Weak::Set#to_a#size     27.713k (± 5.3%) i/s   (36.08 μs/i) -    139.644k in   5.055454s
#
# Comparison:
#         Weak::Set#size:    31010.6 i/s
#    Weak::Set#to_a#size:    27712.9 i/s - 1.12x  slower

# Weak::Set::WeakKeysWithDelete
# ruby 3.4.1 (2024-12-25 revision 48d4efcb85) +YJIT +PRISM [arm64-darwin24]
# Warming up --------------------------------------
#         Weak::Set#size     4.446M i/100ms
#    Weak::Set#to_a#size    12.774k i/100ms
# Calculating -------------------------------------
#         Weak::Set#size     49.978M (± 1.6%) i/s   (20.01 ns/i) -    253.400M in   5.071494s
#    Weak::Set#to_a#size    123.907k (± 2.4%) i/s    (8.07 μs/i) -    625.926k in   5.054222s
#
# Comparison:
#         Weak::Set#size: 49978373.6 i/s
#    Weak::Set#to_a#size:   123907.4 i/s - 403.35x  slower
#
