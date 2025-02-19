# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require "rspec"

if ENV["COVERAGE"] == "1"
  require "simplecov"

  if ENV["CI"]
    require "coveralls"
    SimpleCov.formatter = Coveralls::SimpleCov::Formatter
  else
    SimpleCov.formatter = SimpleCov::Formatter::HTMLFormatter
  end

  SimpleCov.start do
    project_name "WeakSet"
    add_filter "/spec/"
  end

  # Load `weak_set/version.rb` again to get proper coverage data. This file is
  # already loaded by bundler before SimpleCov starts during evaluation of the
  # the `weak_set.gemspec` file
  begin
    warn_level, $VERBOSE = $VERBOSE, nil
    load File.expand_path("../lib/weak_set/version.rb", __dir__)
  ensure
    $VERBOSE = warn_level
  end
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "weak_set"

class WeakSet
  module RSpecHelpers
    # We sometimes need to use a separate scope to ensure that JRuby and older
    # Rubies do not hold any internal references to objects which would prevent
    # their garbage collection during the spec.
    #
    # JRuby can work with any new scope, e.g. a separate method call or a block.
    # Ruby < 3.3 aparently is not happy with just a block scope and needs
    # something "heavier" to break any remaining local references.
    #
    # To solve both peculiarities we use a new thread for the test setup. To
    # avoid cluttering test output when an expectation in a thread is missed, we
    # disable error reporting here.
    #
    # For actual users of a WeakSet, this shouldn't matter much. Depending on
    # their Ruby engine and version, they may just experience delayed garbage
    # collection of values and thus possible WeakSet elements.
    #
    # See https://github.com/jruby/jruby/discussions/8640
    def collectable(&block)
      Thread.new do
        Thread.current.report_on_exception = false
        block.call
      end.value
    end

    def enumerable_mock(obj, method = :each)
      each = instance_double(Enumerator)
      allow(each).to receive(:respond_to?) { |m| m == method }
      allow(each).to receive(method) do |&block|
        obj.each(&block)
      end
      each
    end

    def garbage_collect_until(timeout = 5)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      loop do
        case RUBY_ENGINE
        when "jruby"
          require "java"
          Java::JavaLang::System.gc
          Java::JavaLang::System.runFinalization
        else
          GC.start
        end

        break yield
      rescue RSpec::Expectations::ExpectationNotMetError
        now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        raise if now - started > timeout
      end
    end

    def weak_module
      WeakSet.ancestors.find { |m| m.name.start_with?("WeakSet::") }
    end
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.include WeakSet::RSpecHelpers

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

RSpec::Matchers.define_negated_matcher :not_be_frozen, :be_frozen
RSpec::Matchers.define_negated_matcher :not_eq, :eq
RSpec::Matchers.define_negated_matcher :not_equal, :equal
RSpec::Matchers.define_negated_matcher :not_include, :include
