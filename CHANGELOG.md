# Changelog

All notable changes to this project will be documented in this file.

This project adheres to [Semantic Versioning](https://semver.org).

<!--
Note: In this file, do not use the hard wrap in the middle of a sentence for compatibility with GitHub comment style markdown rendering.
-->

## [Unreleased]

- Support `features`, `no-default-features`, and `all-features` input options. ([#9](https://github.com/taiki-e/cache-cargo-install-action/pull/9), thanks @AlexTMjugador)

- Support more host architectures.

## [2.2.0] - 2025-06-29

- Support AArch64 Windows. ([416e06a](https://github.com/taiki-e/cache-cargo-install-action/commit/416e06a71d56b46522f4853a13720491b1e04f8a))

## [2.1.2] - 2025-06-18

- Fix installation failure on Ubuntu 24.04 due to HTTP 403 error on requests to crates.io. ([#11](https://github.com/taiki-e/cache-cargo-install-action/pull/11), thanks @ctz)

## [2.1.1] - 2025-02-05

- Fix regression on Windows introduced in 2.1.0.

## [2.1.0] - 2025-01-20

- Improve support for Alpine based containers/self-hosted runners (no longer need to install bash in advance).

## [2.0.1] - 2024-06-10

- Workaround [glibc compatibility issue on archlinux](https://github.com/taiki-e/install-action/issues/521).

## [2.0.0] - 2024-04-26

- Update `actions/cache` from 3 to 4. ([#3](https://github.com/taiki-e/cache-cargo-install-action/pull/3))

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

[Unreleased]: https://github.com/taiki-e/cache-cargo-install-action/compare/v2.2.0...HEAD
[2.2.0]: https://github.com/taiki-e/cache-cargo-install-action/compare/v2.1.2...v2.2.0
[2.1.2]: https://github.com/taiki-e/cache-cargo-install-action/compare/v2.1.1...v2.1.2
[2.1.1]: https://github.com/taiki-e/cache-cargo-install-action/compare/v2.1.0...v2.1.1
[2.1.0]: https://github.com/taiki-e/cache-cargo-install-action/compare/v2.0.1...v2.1.0
[2.0.1]: https://github.com/taiki-e/cache-cargo-install-action/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/taiki-e/cache-cargo-install-action/compare/v1.4.0...v2.0.0
[1.4.0]: https://github.com/taiki-e/cache-cargo-install-action/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/taiki-e/cache-cargo-install-action/compare/v1.2.2...v1.3.0
[1.2.2]: https://github.com/taiki-e/cache-cargo-install-action/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/taiki-e/cache-cargo-install-action/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/taiki-e/cache-cargo-install-action/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/taiki-e/cache-cargo-install-action/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/taiki-e/cache-cargo-install-action/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/taiki-e/cache-cargo-install-action/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/taiki-e/cache-cargo-install-action/releases/tag/v1.0.0
