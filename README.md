# cache-cargo-install-action

[![release](https://img.shields.io/github/release/taiki-e/cache-cargo-install-action?style=flat-square&logo=github)](https://github.com/taiki-e/cache-cargo-install-action/releases/latest)
[![github actions](https://img.shields.io/github/actions/workflow/status/taiki-e/cache-cargo-install-action/ci.yml?branch=main&style=flat-square&logo=github)](https://github.com/taiki-e/cache-cargo-install-action/actions)

GitHub Action for `cargo install` with cache.

This installs the specified crate using `cargo install` and caches the installed binaries using [actions/cache].
If binaries for the specified crate are already cached, restore the cache instead of calling `cargo install`.

This was originally intended for installing crates that are not supported by [install-action].
For performance and robustness, we recommend using [install-action] if the tool is supported by [install-action].

- [Usage](#usage)
  - [Inputs](#inputs)
  - [Example workflow](#example-workflow)
- [Migrate from/to install-action](#migrate-fromto-install-action)
- [Compatibility](#compatibility)
- [Related Projects](#related-projects)
- [License](#license)

## Usage

### Inputs

| Name   | Required | Description                                                                | Type    | Default |
| ------ |:--------:| -------------------------------------------------------------------------- | ------- | ------- |
| tool   | **true** | Crate to install                                                           | String  |         |
| locked | false    | Use `--locked` flag                                                        | Boolean | true    |
| git    | false    | Install from the specified Git URL (see [action.yml](action.yml) for more) | String  |         |
| tag    | false    | Tag to use when installing from git                                        | String  |         |
| rev    | false    | Specific commit to use when installing from git                            | String  |         |

### Example workflow

To install the latest version:

```yaml
- uses: taiki-e/cache-cargo-install-action@v2
  with:
    tool: cargo-hack
```

To install a specific version, use `@version` syntax:

```yaml
- uses: taiki-e/cache-cargo-install-action@v2
  with:
    tool: cargo-hack@0.5.24
```

You can also omit patch version.
(You can also omit the minor version if the major version is 1 or greater.)

```yaml
- uses: taiki-e/cache-cargo-install-action@v2
  with:
    tool: cargo-hack@0.5
```

## Migrate from/to install-action

This action provides an interface compatible with [install-action].

Therefore, migrating from/to [install-action] is usually just a change of action to be used. (if the tool and version are supported by install-action or install-action's `binstall` fallback)

To migrate from this action to install-action:

```diff
- - uses: taiki-e/cache-cargo-install-action@v2
+ - uses: taiki-e/install-action@v2
    with:
      tool: cargo-hack
```

To migrate from install-action to this action:

```diff
- - uses: taiki-e/install-action@v2
+ - uses: taiki-e/cache-cargo-install-action@v2
    with:
      tool: cargo-hack
```

The interface of this action is a subset of the interface of [install-action], so note the following limitations when migrating from install-action to this action.

- install-action supports specifying multiple crates in a single action call, but this action does not.

  For example, in install-action, you can write:

  ```yaml
  - uses: taiki-e/install-action@v2
    with:
      tool: cargo-hack,cargo-minimal-versions
  ```

  In this action, you need to write:

  ```yaml
  - uses: taiki-e/cache-cargo-install-action@v2
    with:
      tool: cargo-hack
  - uses: taiki-e/cache-cargo-install-action@v2
    with:
      tool: cargo-minimal-versions
  ```

- install-action supports `@<tool_name>` shorthand, but this action does not.

## Compatibility

This action has been tested for GitHub-hosted runners (Ubuntu, macOS, Windows) and containers (Ubuntu, Debian, Fedora, Alma, Arch, Alpine).
To use this action in self-hosted runners or in containers, at least the following tools are required:

- bash
- GNU tar
- cargo

## Related Projects

- [install-action]: GitHub Action for installing development tools (mainly from GitHub Releases).
- [create-gh-release-action]: GitHub Action for creating GitHub Releases based on changelog.
- [upload-rust-binary-action]: GitHub Action for building and uploading Rust binary to GitHub Releases.
- [setup-cross-toolchain-action]: GitHub Action for setup toolchains for cross compilation and cross testing for Rust.

[actions/cache]: https://github.com/actions/cache
[create-gh-release-action]: https://github.com/taiki-e/create-gh-release-action
[install-action]: https://github.com/taiki-e/install-action
[setup-cross-toolchain-action]: https://github.com/taiki-e/setup-cross-toolchain-action
[upload-rust-binary-action]: https://github.com/taiki-e/upload-rust-binary-action

## License

Licensed under either of [Apache License, Version 2.0](LICENSE-APACHE) or
[MIT license](LICENSE-MIT) at your option.

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the Apache-2.0 license, shall
be dual licensed as above, without any additional terms or conditions.
