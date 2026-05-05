# Changelog

## [Unreleased]

### Changed

- Improve documentation for `Weak::Set#delete?`
- Clarify humanistic usage policy
- Update Github actions
- Use [Common Changelog](https://common-changelog.org) style for the entire changelog

### Added

- Add documentation for remaining `Weak::Cache` methods.
- Run specs for JRuby 10.1

### Fixed

- Fix error reporting on Github CI

## [0.3.1] - 2026-01-16

### Fixed

- Update changelog of 0.3.0 release

## [0.3.0] - 2026-01-16

### Changed

- Adapt `Weak::Set#inspect` output to more resemble the output of `Set#inspect` in Ruby 4.0
- Fix typos in code documentation
- Use `require_relative` instead of require for all gem files
- Clarify humanistic usage policy

### Added

- Add `Weak::Cache` as a thread-safe wrapper around `Weak::Map` to provide an object cache.
- Add addititional specs for `Weak::Map`

### Fixed

- Fix `Weak::Map#store` method alias to `Weak::Map#[]=`. Previously, it was erroneously aliased to `Weak::Map#[]`.

## [0.2.1] - 2025-12-27

### Changed

- Ignore some unnecessary methods defined on some `Weak::Set` implementations in `set_spec`
- Extract `UNDEFINED` to its own file and require it where used.

### Added

- Add more details about the gem version in `Weak::Version`
- Run specs on JRuby 10 in Github Actions

### Fixed

- Handle object cycles in `pretty_print`.
- Retry TruffleRuby rspec runs on Github Actions to avoid random failures due to flakey GC.
- Fix typos in code documentation

## [0.2.0] - 2025-04-09

### Added

- Add `Weak::Map#delete_if`
- Add `Weak::Map#keep_if`
- Add `Weak::Map#reject!`
- Add `Weak::Map#replace`
- Add `Weak::Map#select!`
- Add `Weak::Map#values_at`

## [0.1.0] - 2025-03-14

### Added

- Initial version of `Weak::Set` to store an unordered collection of objects.
- Initial version of `Weak::Map` to store key-value pairs of objects.
- Support for Ruby 3.0 using the following impementations
    - Ruby (aka. MRI, aka. YARV) >= 3.0
    - JRuby >= 9.4
    - TruffleRuby >= 22

## [0.0.1.pre] - 2025-02-05

First blank slate
