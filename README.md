# WeakSet

[![gem version badge](https://badge.fury.io/rb/weak_set.svg)](https://rubygems.org/gems/weak_set)
[![CI status badge](https://github.com/meineerde/weak_set/workflows/CI/badge.svg)](https://github.com/meineerde/weak_set/actions?query=workflow%3ACI)
[![Coverage Status](https://coveralls.io/repos/github/meineerde/weak_set/badge.svg?branch=main)](https://coveralls.io/github/meineerde/weak_set?branch=main)

WeakSet is a Ruby library which implements a collection of unordered values without strong object references.

It behaves similar to the [Set](https://docs.ruby-lang.org/en/3.4/Set.html) class of the Ruby standard library, but all values are only weakly referenced. That way, all values can be garbage collected and silently removed from the set unless they are still referenced from some other live object.

```ruby
require "weak_set"
set = WeakSet.new

set << "some string"
# => #<WeakSet: {"some string"}>

# Do some work, wait a bit, or force a garbage collection run
3.times { GC.start }

set
# => #<WeakSet: {}>
```

## Usage

Please refer to the documentation at:

- [📘 Documentation](https://www.rubydoc.info/gems/weak_set)
- [💥 Development Documentation](https://www.rubydoc.info/github/meineerde/weak_set/main) of the [main branch](https://github.com/meineerde/weak_set/tree/main)

> [!WARNING]
> WeakSet is not inherently thread-safe. When accessing a WeakSet from multiple threads or fibers, you MUST use a mutex or another locking mechanism.

WeakSet uses Ruby's [ObjectSpace::WeakMap](https://docs.ruby-lang.org/en/3.4/ObjectSpace/WeakMap.html) under the hood. Unfortunately, different Ruby implementations and versions such as Ruby (aka. MRI, aka. YARV), JRuby, or TruffleRuby show quite diverse behavior in their respective `ObjectSpace::WeakMap` implementations. To provide a unified behavior on all supported Rubies, we use multiple different storage strategies.

The appropriate strategy is selected automatically. Their exposed behavior should be identical across all implementations. If you experience diverging behavior, we consider this a bug. Please [open an issue](https://github.com/meineerde/weak_set/issues/new) and describe the diverging or unexpected behavior.

## Installation

WeakSet supports the following Ruby implementation:

- Ruby (aka. MRI, aka. YARV) >= 3.0
- JRuby >= 9.4
- TruffleRuby >= 22

Add the `weak_set` gem to the application's `Gemfile` and install it by executing:

```sh
bundle add weak_set
```

If [bundler](https://bundler.io/) is not being used to manage dependencies, install the gem manually by executing:

```sh
gem install weak_set
```

## Example

A WeakSet can be used as a cache or for validation purposes were it is not desirable to keep a full object reference. For example, it can be used with a basic `ConnectionPool` as follows

```ruby
require "weak_set"

class Connection
  # A sample connection class.
  # Our ConnectionPool will return objects from this class.
end

class ConnectionPool
  def initialize
    @pool = []
    @outstanding = WeakSet.new
    @mutex = Mutex.new
  end

  # Fetch or create a connection object. The connection object can (but does not
  # have to) be returned to the pool again with `checkin`.
  def checkout
    @mutex.synchronize do
      connection = @pool.pop || Connection.new
      @outstanding << connection

      connection
    end
  end

  # Allows to return a previously checked-out connection object back to the pool
  # for later re-use. Only connection objects which were previously checked-out
  # can be returned to the pool.
  def checkin(connection)
    @mutex.synchronize do
      if @outstanding.delete?(connection)
        @pool.push connection
      else
        raise ArgumentError, "connection was not checked out before"
      end
    end

    nil
  end

  # Fetch or create a connection object and yield it to the given block. After
  # the block completes, the connection is automatically checked-in again for
  # later re-use. The method returns the return value of the block.
  def with
    connection = checkout
    begin
      yield connection
    ensure
      checkin(connection)
    end
  end
end
```

During `checkout` we remember a reference to the returned connection object in the `@outstanding` weak set. The caller is free to do whatever they like with the connection. Specifically, they are not required to return the connection to the pool.

If the caller just "forgets" the connection, our pool will also forget it during the next Ruby garbage collection run.

If the caller returns the connection by calling `checkin` again, we can verify that we have in fact created the object by deleting it from the `@outstanding` list. That way, the a checked-out connection can be checked-in again only once and only if it was initially created by the `ConnectionPool`.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

[![code style: standard badge](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/standardrb/standard)

We follow the Standard Ruby style. Please make sure that all code is formatted according to the Standard rules. This is enforced by the CI. Please try to keep all code lines at or below 100 characters in length.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/meineerde/weak_set. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/meineerde/weak_set/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the WeakSet project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/meineerde/weak_set/blob/main/CODE_OF_CONDUCT.md).
