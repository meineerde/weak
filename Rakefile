# frozen_string_literal: true

# Copyright (c) Holger Just
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE.txt file for details.

require "bundler/gem_tasks"

begin
  require "yard"
rescue LoadError
  # yard ist not available, likely `bundle --without doc`
else
  YARD::Rake::YardocTask.new
  task doc: :yard
end

default_tasks = []

begin
  require "rspec/core/rake_task"
rescue LoadError
  # rspec is not available, likely `bundle --without test`
else
  RSpec::Core::RakeTask.new(:spec) do |t|
    t.rspec_opts = %w[--format documentation]
  end

  default_tasks << :spec
end

begin
  require "standard/rake"
rescue LoadError
  # standard is not available, likely `bundle --without test`
else
  default_tasks << :standard
end

task default: default_tasks
