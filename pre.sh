#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -CeEuo pipefail
IFS=$'\n\t'

retry() {
  for i in {1..10}; do
    if "$@"; then
      return 0
    else
      sleep "${i}"
    fi
  done
  "$@"
}
bail() {
  printf '::error::%s\n' "$*"
  exit 1
}
warn() {
  printf '::warning::%s\n' "$*"
}
info() {
  printf >&2 'info: %s\n' "$*"
}
_sudo() {
  if type -P sudo >/dev/null; then
    sudo "$@"
  else
    "$@"
  fi
}
download_and_checksum() {
  local url="${1:?}"
  local checksum="${2:?}"
  retry curl --proto '=https' --tlsv1.2 -fsSL --retry 10 "${url}" -o tmp
  if type -P sha256sum >/dev/null; then
    sha256sum -c - >/dev/null <<<"${checksum} *tmp"
  elif type -P shasum >/dev/null; then
    # GitHub-hosted macOS runner does not install GNU Coreutils by default.
    # https://github.com/actions/runner-images/issues/90
    shasum -a 256 -c - >/dev/null <<<"${checksum} *tmp"
  else
    warn "checksum requires 'sha256sum' or 'shasum' command; consider installing one of them; skipped checksum for $(basename -- "${url}")"
  fi
}
apt_update() {
  retry _sudo apt-get -o Acquire::Retries=10 -qq update
  apt_updated=1
}
apt_install() {
  if [[ -z "${apt_updated:-}" ]]; then
    apt_update
  fi
  retry _sudo apt-get -o Acquire::Retries=10 -o Dpkg::Use-Pty=0 install -y --no-install-recommends "$@"
}
dnf_install() {
  retry _sudo "${dnf}" install -y "$@"
}
pacman_install() {
  retry _sudo pacman -Sy --noconfirm "$@"
}
apk_install() {
  if type -P sudo >/dev/null; then
    retry sudo apk --no-cache add "$@"
  elif type -P doas >/dev/null; then
    retry doas apk --no-cache add "$@"
  else
    retry apk --no-cache add "$@"
  fi
}
sys_install() {
  case "${base_distro}" in
    debian) apt_install "$@" ;;
    fedora) dnf_install "$@" ;;
    arch) pacman_install "$@" ;;
    alpine) apk_install "$@" ;;
  esac
}

# Inputs
tool="${INPUT_TOOL:?}"
locked="${INPUT_LOCKED:?}"
git="${INPUT_GIT:-}"
tag="${INPUT_TAG:-}"
rev="${INPUT_REV:-}"

# Refs: https://github.com/rust-lang/rustup/blob/HEAD/rustup-init.sh
base_distro=''
case "$(uname -s)" in
  Linux)
    ldd_version=$(ldd --version 2>&1 || true)
    if grep -Fq musl <<<"${ldd_version}"; then
      host_os="linux-musl"
    else
      host_glibc_version=$(grep -E "GLIBC|GNU libc" <<<"${ldd_version}" | sed -E "s/.* //g")
      host_os="linux-gnu-${host_glibc_version}"
    fi
    if grep -Eq '^ID_LIKE=' /etc/os-release; then
      base_distro=$(grep -E '^ID_LIKE=' /etc/os-release | cut -d= -f2)
      case "${base_distro}" in
        *debian*) base_distro=debian ;;
        *fedora*) base_distro=fedora ;;
        *arch*) base_distro=arch ;;
        *alpine*) base_distro=alpine ;;
      esac
    else
      base_distro=$(grep -E '^ID=' /etc/os-release | cut -d= -f2)
    fi
    base_distro="${base_distro//\"/}"
    case "${base_distro}" in
      fedora)
        dnf=dnf
        if ! type -P dnf >/dev/null; then
          if type -P microdnf >/dev/null; then
            # fedora-based distributions have "minimal" images that
            # use microdnf instead of dnf.
            dnf=microdnf
          else
            # If neither dnf nor microdnf is available, it is
            # probably an RHEL7-based distribution that does not
            # have dnf installed by default.
            dnf=yum
          fi
        fi
        ;;
    esac
    ;;
  Darwin) host_os=macos ;;
  MINGW* | MSYS* | CYGWIN* | Windows_NT) host_os=windows ;;
  *) bail "unrecognized OS type '$(uname -s)'" ;;
esac
host_arch="$(uname -m)"
case "${host_arch}" in
  aarch64 | arm64) host_arch=aarch64 ;;
  # On these platforms, we can just use the result of `uname -m` as host_arch.
  xscale | arm | armv*l | loongarch64 | ppc | ppc64 | ppc64le | riscv64 | s390x | sun4v) ;;
  # Ignore MIPS for now, as we also need to detect endianness.
  mips | mips64)
    bail "MIPS runner is not supported yet by this action; if you need support for this platform, please submit an issue at <https://github.com/taiki-e/cache-cargo-install-action>"
    ;;
  # GitHub Actions Runner supports Linux (x86_64, AArch64, Arm), Windows (x86_64, AArch64),
  # and macOS (x86_64, AArch64).
  # https://github.com/actions/runner/blob/v2.321.0/.github/workflows/build.yml#L21
  # https://docs.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners#supported-architectures-and-operating-systems-for-self-hosted-runners
  # So we can assume x86_64 unless it is AArch64 or Arm.
  *)
    host_arch=x86_64
    # Do additional check on Windows because uname -m on windows-11-arm returns "x86_64".
    if [[ "${host_os}" == "windows" ]]; then
      host=$(rustc -vV | grep -E '^host:' | cut -d' ' -f2)
      case "${host}" in
        aarch64* | arm64*) host_arch=aarch64 ;;
      esac
    fi
    ;;
esac

if [[ "${tool}" == *","* ]]; then
  bail "cache-cargo-install-action does not support specifying multiple crates yet; consider calling this action per crate"
fi
fetch=''
if [[ "${tool}" == *"@"* ]]; then
  if [[ -n "${git}" ]]; then
    bail "<tool>@<version> syntax is not supported with 'git' input option"
  fi
  version="${tool#*@}"
  tool="${tool%@*}"
  if [[ ! "${version}" =~ ^([1-9][0-9]*\.[0-9]+\.[0-9]+|0\.[1-9][0-9]*\.[0-9]+|^0\.0\.[0-9]+)(-[0-9A-Za-z\.-]+)?(\+[0-9A-Za-z\.-]+)?$|^latest$ ]]; then
    if [[ ! "${version}" =~ ^([1-9][0-9]*(\.[0-9]+(\.[0-9]+)?)?|0\.[1-9][0-9]*(\.[0-9]+)?|^0\.0\.[0-9]+)(-[0-9A-Za-z\.-]+)?(\+[0-9A-Za-z\.-]+)?$|^latest$ ]]; then
      bail "cache-cargo-install-action does not support non-semver version: '${version}'"
    fi
    fetch='1'
  fi
elif [[ -n "${git}" ]]; then
  if [[ -n "${tag}" ]] && [[ -n "${rev}" ]]; then
    bail "'tag' and 'rev' input options cannot be used together"
  fi
  if [[ -z "${tag}" ]] && [[ -z "${rev}" ]]; then
    bail "'git' input option currently requires one of 'tag' or 'rev' input option"
  fi
  version=''
else
  version=latest
fi

case "${locked}" in
  true)
    locked=--locked
    locked_key=''
    ;;
  false)
    locked=''
    locked_key=-locked-false
    ;;
  *) bail "'locked' input option must be 'true' or 'false': '${locked}'" ;;
esac

if [[ "${version}" == "latest" ]] || [[ -n "${fetch}" ]]; then
  install_action_dir="${HOME}/.cache-cargo-install-action"
  case "${host_os}" in
    linux*)
      if ! type -P jq >/dev/null || ! type -P curl >/dev/null; then
        case "${base_distro}" in
          debian | fedora | arch | alpine)
            printf '::group::Install packages required for installation (jq and/or curl)\n'
            sys_packages=()
            if ! type -P curl >/dev/null; then
              sys_packages+=(ca-certificates curl)
            fi
            if [[ "${dnf:-}" == "yum" ]]; then
              # On RHEL7-based distribution jq requires EPEL
              if ! type -P jq >/dev/null; then
                sys_packages+=(epel-release)
                sys_install "${sys_packages[@]}"
                sys_install jq --enablerepo=epel
              else
                sys_install "${sys_packages[@]}"
              fi
            else
              if ! type -P jq >/dev/null; then
                # https://github.com/taiki-e/install-action/issues/521
                if [[ "${base_distro}" == "arch" ]]; then
                  sys_packages+=(glibc)
                fi
                sys_packages+=(jq)
              fi
              sys_install "${sys_packages[@]}"
            fi
            printf '::endgroup::\n'
            ;;
          *) warn "cache-cargo-install-action requires jq and curl on non-Debian/Fedora/Arch/Alpine-based Linux" ;;
        esac
      fi
      ;;
    macos)
      if ! type -P jq >/dev/null || ! type -P curl >/dev/null; then
        warn "cache-cargo-install-action requires jq and curl on macOS"
      fi
      ;;
    windows)
      if ! type -P curl >/dev/null; then
        warn "cache-cargo-install-action requires curl on Windows"
      fi
      if [[ -f "${install_action_dir}/jq/bin/jq.exe" ]]; then
        jq() { "${install_action_dir}/jq/bin/jq.exe" -b "$@"; }
      elif type -P jq >/dev/null; then
        # https://github.com/jqlang/jq/issues/1854
        _tmp=$(jq -r .a <<<'{}')
        if [[ "${_tmp}" != "null" ]]; then
          _tmp=$(jq -b -r .a 2>/dev/null <<<'{}' || true)
          if [[ "${_tmp}" == "null" ]]; then
            jq() { command jq -b "$@"; }
          else
            jq() { command jq "$@" | tr -d '\r'; }
          fi
        fi
      else
        printf '::group::Install packages required for installation (jq)\n'
        mkdir -p -- "${install_action_dir}/jq/bin"
        url='https://github.com/jqlang/jq/releases/download/jq-1.8.1/jq-windows-amd64.exe'
        checksum='23cb60a1354eed6bcc8d9b9735e8c7b388cd1fdcb75726b93bc299ef22dd9334'
        (
          cd -- "${install_action_dir}/jq/bin"
          download_and_checksum "${url}" "${checksum}"
          mv -- tmp jq.exe
        )
        printf '::endgroup::\n'
        jq() { "${install_action_dir}/jq/bin/jq.exe" -b "$@"; }
      fi
      ;;
    *) bail "unsupported host OS '${host_os}'" ;;
  esac

  crate_info=$(retry curl -v --user-agent "${ACTION_USER_AGENT}" --proto '=https' --tlsv1.2 -fsSL --retry 10 "https://crates.io/api/v1/crates/${tool}")
  case "${version}" in
    latest)
      version=$(jq -r '.crate.max_stable_version' <<<"${crate_info}")
      if [[ "${version}" == "null" ]]; then
        bail "no stable version found for ${tool}; if you want to install a pre-release version, please specify the full version"
      fi
      ;;
    *)
      if [[ ! "${version}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        bail "cache-cargo-install-action does not support non-semver version: '${version}'"
      fi
      # shellcheck disable=SC2207
      versions=($(jq -r ".versions[] | select(.num | startswith(\"${version}.\")) | select(.yanked == false) | .num" <<<"${crate_info}"))
      full_version=''
      for v in ${versions[@]+"${versions[@]}"}; do
        if [[ ! "${v}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(\+[0-9A-Za-z\.-]+)?$ ]]; then
          continue
        fi
        full_version="${v}"
        break
      done
      if [[ -z "${full_version}" ]]; then
        bail "no stable version  found for ${tool} that match with '${version}.*'; if you want to install a pre-release version, please specify the full version"
      fi
      version="${full_version}"
      ;;
  esac
fi

bin_dir="${RUNNER_TOOL_CACHE}/${tool}/bin"
printf '%s\n' "${bin_dir}" >>"${GITHUB_PATH}"

if [[ -n "${git}" ]]; then
  key="${tool}-git-${tag:+"tag-${tag}"}${rev:+"rev-${rev}"}-${host_arch}-${host_os}${locked_key}"
else
  key="${tool}-${version}-${host_arch}-${host_os}${locked_key}"
fi
cat >>"${GITHUB_OUTPUT}" <<EOF
tool=${tool}
version=${version}
key=${key}
path=${bin_dir}
locked=${locked}
git=${git}
tag=${tag}
rev=${rev}
EOF
