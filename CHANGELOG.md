# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org).

<!--
Note: In this file, do not use the hard wrap in the middle of a sentence for compatibility with GitHub comment style markdown rendering.
-->

## [Unreleased]

- Update `actions/cache` from 3 to 4.

  This [breaks compatibility with CentOS 7 and Ubuntu 18.04](https://github.com/actions/runner/issues/2906) so it is treated as a breaking change.

## [1.4.0] - 2024-04-26

- Improve support for Arch based containers/self-hosted runners.

## [1.3.0] - 2023-10-15

- Add `git` input option to install from the specified Git URL.

## [1.2.2] - 2023-09-16

- Fix potential bug on Windows self-hosted runner.

## [1.2.1] - 2023-07-31

- Improve performance and robustness for cases where the host environment lacks the packages required for installation, such as containers or self-hosted runners.

## [1.2.0] - 2023-05-06

- Add `locked` input option (default to `true`) to allow choice of whether or not to use `--locked` flag.

## [1.1.1] - 2023-01-14

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

[Unreleased]: https://github.com/taiki-e/cache-cargo-install-action/compare/v1.4.0...HEAD
[1.4.0]: https://github.com/taiki-e/cache-cargo-install-action/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/taiki-e/cache-cargo-install-action/compare/v1.2.2...v1.3.0
[1.2.2]: https://github.com/taiki-e/cache-cargo-install-action/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/taiki-e/cache-cargo-install-action/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/taiki-e/cache-cargo-install-action/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/taiki-e/cache-cargo-install-action/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/taiki-e/cache-cargo-install-action/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/taiki-e/cache-cargo-install-action/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/taiki-e/cache-cargo-install-action/releases/tag/v1.0.0
