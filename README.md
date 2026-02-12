# Weak

[![gem version badge](https://badge.fury.io/rb/weak.svg)](https://rubygems.org/gems/weak)
[![license badge](https://img.shields.io/badge/license-MIT-brightgreen.svg)](https://github.com/meineerde/weak/blob/main/LICENSE.txt)
[![github repo badge](https://img.shields.io/badge/github-meineerde/weak-blue.svg)](https://github.com/meineerde/weak)
[![documentation badge](https://img.shields.io/badge/docs-rubydoc.info-blue.svg)](https://www.rubydoc.info/gems/weak)

[![code style: standard badge](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/standardrb/standard)
[![CI status badge](https://github.com/meineerde/weak/actions/workflows/ci.yml/badge.svg)](https://github.com/meineerde/weak/actions/workflows/ci.yml)
[![Coverage Status](https://coveralls.io/repos/github/meineerde/weak/badge.svg?branch=main)](https://coveralls.io/github/meineerde/weak?branch=main)

Weak is a Ruby library which implements collections of unordered values with weak object references.

We provide multiple classes which behave similar to their standard-library counterparts. However, all elements are only weakly referenced. That way, all elements can be garbage collected and silently removed from the collection unless they are still referenced from some other live object.

## Weak::Set 

[`Weak::Set`](https://www.rubydoc.info/gems/weak/Weak/Set) behaves similar to the [Set](https://docs.ruby-lang.org/en/3.4/Set.html) class of the Ruby standard library, but all values are only weakly referenced. That way, all values can be garbage collected and silently removed from the set unless they are still referenced from some other live object.

> [!CAUTION]
> `Weak::Set` objects are not inherently thread-safe. When accessing a weak set from multiple threads or fibers, you MUST use a mutex or another locking mechanism.

Compared to the `Set` class, there are a few differences:

  - All element references are weak, allowing each element to be garbage collected unless there is a strong reference to it somwhere else.
  - We do not necessarily retain the order of elements as they are inserted into the `Weak::Set`. You should not rely on a specific order.
  - Set membership is governed by object identity rather than by using the `hash` and `eql?` methods of the elements. A `Weak::Set` thus works similat to a `Set` marked as [compare_by_identity](https://docs.ruby-lang.org/en/3.4/Set.html#method-i-compare_by_identity).
  - You can freely change any objects added to the `Weak::Set`.

```ruby
require "weak/set"
set = Weak::Set.new

set << "some string"
# => Weak::Set["some string"]

# Do some work, wait a bit, or force a garbage collection run
3.times { GC.start }

set
# => Weak::Set[]
```

## Weak::Map

[`Weak::Map`](https://www.rubydoc.info/gems/weak/Weak/Map) behaves similar to a `Hash` or an `ObjectSpace::WeakMap` in Ruby (aka. MRI, aka. YARV). 
Both keys and values are weak references, allowing either of them to be garbage collected. If either the key or the value of a pair is garbage collected, the entire pair will be removed from the `Weak::Map`.

> [!CAUTION]
> `Weak::Map` objects are not inherently thread-safe. When accessing a weak map from multiple threads or fibers, you MUST use a mutex or another locking mechanism. You can also use `Weak::Cache` as a thread-safe option.

Compared to the `Hash` class, there are a few differences:

  - Key and value references are weak, allowing each key-value pair to be garbage collected unless there is a strong reference to boith the key and the value somewhere else.
  - We do not necessarily retain the order of elements as they are inserted into the `Weak::Map`. You should not rely on a specific order.
  - Map membership is governed by object identity of the key rather than by using its `hash` and `eql?` methods. A `Weak::Map` thus works similar to a `Hash` marked as [compare_by_identity](https://docs.ruby-lang.org/en/3.4/Hash.html#method-i-compare_by_identity).
  - You can freely change both keys and values added to the `Weak::Map`.

```ruby
require "weak/map"
map = Weak::Map.new

map["some key"] = "a value"
# => #<Weak::Map {"some key" => "a value"}>

# Do some work, wait a bit, or force a garbage collection run
3.times { GC.start }

map
# => #<Weak::Map {}>
```

## Weak::Cache

[`Weak::Cache`](https://www.rubydoc.info/gems/weak/Weak/Cache) is a thread-safe wrapper around `Weak::Map`. The class behaves similar to an `ActiveSupport::Cache::Store`.

> [!TIP]
> `Weak::Cache` objects can safely be used from multiple threads and fibers concurrently without any additional locks.

Similar to a `Weak:Map`, both keys and values are weak references. Cache entries are removed if either the key of the value is garbage collected.

```ruby
require "weak/cache"
cache = Weak::Cache.new

# By default, we return nil for missing keys
cache[:key] # => nil

# With fetch, we can get a key and if it's missing, write a value for it
cache.fetch(:key) { |key| key.upcase } # => :KEY

# The value stored in the fetch above is stored in the cache
cache[:key] # => :KEY
```

## Usage

Please refer to the documentation at:

- [📘 Documentation](https://www.rubydoc.info/gems/weak)
- [💥 Development Documentation](https://www.rubydoc.info/github/meineerde/weak) of the [main branch](https://github.com/meineerde/weak/tree/main)

The Weak collections use Ruby's [ObjectSpace::WeakMap](https://docs.ruby-lang.org/en/3.4/ObjectSpace/WeakMap.html) under the hood. Unfortunately, different Ruby implementations and versions such as Ruby (aka. MRI, aka. YARV), JRuby, or TruffleRuby show quite diverse behavior in their respective `ObjectSpace::WeakMap` implementations. To provide a unified behavior on all supported Rubies, we use multiple different storage strategies.

The appropriate strategy is selected automatically. Their exposed behavior should be identical across all implementations. If you experience diverging behavior, we consider this a bug. Please [open an issue](https://github.com/meineerde/weak/issues/new) and describe the diverging or unexpected behavior.

## Installation

Weak supports the following Ruby implementation:

- Ruby (aka. MRI, aka. YARV) >= 3.0
- JRuby >= 9.4
- TruffleRuby >= 22

Add the `weak` gem to the application's `Gemfile` and install it by executing:

```sh
bundle add weak
```

If [bundler](https://bundler.io/) is not being used to manage dependencies, install the gem manually by executing:

```sh
gem install weak
```

## Examples

### Weak::Set Example

A Weak::Set can be used as a cache or for validation purposes were it is not desirable to keep a full object reference. For example, it can be used with a basic `ConnectionPool` as follows

```ruby
require "weak/set"

class Connection
  # A sample connection class.
  # Our ConnectionPool will return objects from this class.
end

class ConnectionPool
  def initialize
    @pool = []
    @outstanding = Weak::Set.new
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

If the caller returns the connection by calling `checkin` again, we can verify that we have in fact created the object by deleting it from the `@outstanding` list. That way, a checked-out connection can be checked-in again only once and only if it was initially created by the `ConnectionPool`.

### Weak::Map Example

Conversely a `Weak::Map` can be used to store references to other objects. In the example below, we use a single `Mutex` for each `obj` wrapped in a `LockedObject` instance.

Even if a single object is wrapped in multiple `LockedObject` instances, we still use the same shared mutex in each of these instances, ensuring that the `obj` is only every accessed while holding the mutex. Different objects use different mutexes.

If all LockedObject instances for an `obj` and the `obj` itself vanish by being garbage collected, the associated mutex will also be garbage collected without requiring any external coordination.

```ruby
require "weak/map"

class LockedObject < BasicObject
  LOCKS = Weak::Map.new
  LOCKS_MUTEX = Mutex.new

  def initialize(obj)
    @obj = obj

    # Assigning the obj mutex must itself be wrapped in a different mutex as a Weak::Map
    # is not thread-safe. We retain the mutex for obj in @mutex for the LockedObject
    # instance.
    LOCKS_MUTEX.synchronize do
      @mutex = (LOCKS[obj] ||= Mutex.new)
    end
  end

  private

  def method_missing(m, *args, **kwargs, &block)
    @mutex.synchronize do
      obj.public_send(m, *args, **kwargs, &block)
    end
  end

  def respond_to_missing?(m)
    obj.respond_to?(m)
  end
end

string = "foo"

# As an example, we simulate concurrent access to the string from multiple Threads.
# Especially on JRuby, you would likely see data corruptions without the mutex here.
5.times do
  Thread.new do
    locked = Locked.new(string)
    ("a".."z").each do |char|
      locked << char*2
    end
  end
end
```

### Weak::Cache Example

We can simplify the above example by using `Weak::Cache`.

```ruby
require "weak/cache"

class LockedObject < BasicObject
  LOCKS = Weak::Cache.new

  def initialize(obj)
    @obj = obj
    @mutex = LOCKS.fetch(obj) { Mutex.new }
  end

  private

  def method_missing(m, *args, **kwargs, &block)
    @mutex.synchronize do
      obj.public_send(m, *args, **kwargs, &block)
    end
  end

  def respond_to_missing?(m)
    obj.respond_to?(m)
  end
end
```

The `LockedObject` class we have defined here works exactly the same the the one in the `Weak::Map` example above. However, it avoids having to use a separate mutex for  accessing the `LOCKS` cache.

In our `LockedObject#initialize`, if the given object already has an associated mutex in the `LOCKS` cache, we return it directly. If there was no previous mutex however, the `fetch` method will call the provided block and will store the result (i.e. the new `Mutex`) in the cache and return it.

Subsequent invocations of `fetch` will return the same mutex again, unless it was garbage collected in the meantime.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

We follow the [Standard Ruby code style](https://github.com/standardrb/standard). Please make sure that all code is formatted according to the Standard rules. This is enforced by the CI. Please try to keep all code lines at or below 100 characters in length.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/meineerde/weak. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/meineerde/weak/blob/main/CODE_OF_CONDUCT.md).

## License and Usage Policy

Weak is available as free and open source under the terms of the [MIT License](https://github.com/meineerde/weak/blob/main/LICENSE.txt).

While this license does not preclude you from using Weak in projects associated with so-called "AI", you do not have the author's consent to do so. This may seem like a contradiction, but copyright is a blunt tool that does not in general have the humanistic nuance to describe something like "you can legally do this thing, but if you do, you're an asshole."

We also explicitly affirm: Trans Rights Are Human Rights. If you do not agree, please refrain from using Weak.

(Thanks to [Cassandra Granade](https://codeberg.org/cgranade/do#license-and-ai-policy) for the inspiration.)

## Code of Conduct

Everyone interacting in the Weak project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/meineerde/weak/blob/main/CODE_OF_CONDUCT.md).
