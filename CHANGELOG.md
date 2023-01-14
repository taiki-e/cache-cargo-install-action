# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org).

<!--
Note: In this file, do not use the hard wrap in the middle of a sentence for compatibility with GitHub comment style markdown rendering.
-->

## [Unreleased]

- Prevent pre-release version from being installed as the latest version when patch/minor version is omitted.

## [1.1.0] - 2023-01-14

- Support omitting the patch/minor version.

  For example:

  ```yaml
  - uses: taiki-e/cache-cargo-install-action@v1
    with:
      tool: cargo-hack@0.5
  ```

  You can also omit the minor version if the major version of tool is 1 or greater.

## [1.0.1] - 2023-01-13

- Remove extra `apk` calls on alpine.

## [1.0.0] - 2023-01-13

Initial release

[Unreleased]: https://github.com/taiki-e/cache-cargo-install-action/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/taiki-e/cache-cargo-install-action/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/taiki-e/cache-cargo-install-action/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/taiki-e/cache-cargo-install-action/releases/tag/v1.0.0
