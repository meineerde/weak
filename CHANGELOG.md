# Changelog

## [Unreleased]

- Adapt `Weak::Set#inspect` output to more resemble the output of `Set#inspect` in Ruby 4.0
- Fix `Weak::Map#store` method alias to `Weak::Map#[]=`. Previously, it was errouneously aliased to `Weak::Map#[]`.
- Fix typos in code documentation

## [0.2.1] - 2025-12-27

- Fix typos in code documentation
- Ignore some unnecessary methods defined on some `Weak::Set` implementations in `set_spec`
- Run specs on JRuby 10 in Github Actions
- Retry TruffleRuby rspec runs on Github Actions to avoid random failures due to flakey GC.
- Extract `UNDEFINED` to its own file and require it where used.
- Add more details about the gem version in `Weak::Version`
- Handle object cycles in `pretty_print`.

## [0.2.0] - 2025-04-09

- Add `Weak::Map#delete_if`
- Add `Weak::Map#keep_if`
- Add `Weak::Map#reject!`
- Add `Weak::Map#replace`
- Add `Weak::Map#select!`
- Add `Weak::Map#values_at`

## [0.1.0] - 2025-03-14

- Initial version of `Weak::Set` to store an unordered collection of objects.
- Initial version of `Weak::Map` to store key-value pairs of objects.
- Support for Ruby 3.0 using the following impementations
    - Ruby (aka. MRI, aka. YARV) >= 3.0
    - JRuby >= 9.4
    - TruffleRuby >= 22

## [0.0.1.pre] - 2025-02-05

- First blank slate
