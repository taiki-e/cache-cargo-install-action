#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -eEuo pipefail
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
    echo "::error::$*"
    exit 1
}
warn() {
    echo "::warning::$*"
}
info() {
    echo "info: $*"
}
_sudo() {
    if type -P sudo &>/dev/null; then
        sudo "$@"
    else
        "$@"
    fi
}
download_and_checksum() {
    local url="${1:?}"
    local checksum="${2:?}"
    retry curl --proto '=https' --tlsv1.2 -fsSL --retry 10 "${url}" -o tmp
    if type -P sha256sum &>/dev/null; then
        echo "${checksum} *tmp" | sha256sum -c - >/dev/null
    elif type -P shasum &>/dev/null; then
        # GitHub-hosted macOS runner does not install GNU Coreutils by default.
        # https://github.com/actions/runner-images/issues/90
        echo "${checksum} *tmp" | shasum -a 256 -c - >/dev/null
    else
        warn "checksum requires 'sha256sum' or 'shasum' command; consider installing one of them; skipped checksum for $(basename "${url}")"
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
    if type -P sudo &>/dev/null; then
        retry sudo apk --no-cache add "$@"
    elif type -P doas &>/dev/null; then
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
base_distro=""
case "$(uname -s)" in
    Linux)
        ldd_version=$(ldd --version 2>&1 || true)
        if grep <<<"${ldd_version}" -q 'musl'; then
            host_os="linux-musl"
        else
            host_glibc_version=$(grep <<<"${ldd_version}" -E "GLIBC|GNU libc" | sed "s/.* //g")
            host_os="linux-gnu-${host_glibc_version}"
        fi
        if grep -q '^ID_LIKE=' /etc/os-release; then
            base_distro=$(grep '^ID_LIKE=' /etc/os-release | cut -d= -f2)
            case "${base_distro}" in
                *debian*) base_distro=debian ;;
                *fedora*) base_distro=fedora ;;
                *arch*) base_distro=arch ;;
                *alpine*) base_distro=alpine ;;
            esac
        else
            base_distro=$(grep '^ID=' /etc/os-release | cut -d= -f2)
        fi
        case "${base_distro}" in
            fedora)
                dnf=dnf
                if ! type -P dnf &>/dev/null; then
                    if type -P microdnf &>/dev/null; then
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
case "$(uname -m)" in
    aarch64 | arm64) host_arch="aarch64" ;;
    xscale | arm | armv*l)
        # Ignore arm for now, as we need to consider the version and whether hard-float is supported.
        # https://github.com/rust-lang/rustup/pull/593
        # https://github.com/cross-rs/cross/pull/1018
        # Does it seem only armv7l+ is supported?
        # https://github.com/actions/runner/blob/v2.315.0/src/Misc/externals.sh#L189
        # https://github.com/actions/runner/issues/688
        bail "32-bit ARM runner is not supported yet by this action; if you need support for this platform, please submit an issue at <https://github.com/taiki-e/cache-cargo-install-action>"
        ;;
    # GitHub Actions Runner supports Linux (x86_64, aarch64, arm), Windows (x86_64, aarch64),
    # and macOS (x86_64, aarch64).
    # https://github.com/actions/runner/blob/v2.315.0/.github/workflows/build.yml#L21
    # https://docs.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners#supported-architectures-and-operating-systems-for-self-hosted-runners
    # So we can assume x86_64 unless it is aarch64 or arm.
    *) host_arch="x86_64" ;;
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
    version=""
else
    version="latest"
fi

case "${locked}" in
    true)
        locked="--locked"
        locked_key=''
        ;;
    false)
        locked=''
        locked_key="-locked-false"
        ;;
    *) bail "'locked' input option must be 'true' or 'false': '${locked}'" ;;
esac

if [[ "${version}" == "latest" ]] || [[ -n "${fetch}" ]]; then
    install_action_dir="${HOME}/.cache-cargo-install-action"
    jq_use_b=''
    case "${host_os}" in
        linux*)
            if ! type -P jq &>/dev/null || ! type -P curl &>/dev/null; then
                case "${base_distro}" in
                    debian | fedora | arch | alpine)
                        echo "::group::Install packages required for installation (jq and/or curl)"
                        sys_packages=()
                        if ! type -P curl &>/dev/null; then
                            sys_packages+=(ca-certificates curl)
                        fi
                        if [[ "${dnf:-}" == "yum" ]]; then
                            # On RHEL7-based distribution jq requires EPEL
                            if ! type -P jq &>/dev/null; then
                                sys_packages+=(epel-release)
                                sys_install "${sys_packages[@]}"
                                sys_install jq --enablerepo=epel
                            else
                                sys_install "${sys_packages[@]}"
                            fi
                        else
                            if ! type -P jq &>/dev/null; then
                                # https://github.com/taiki-e/install-action/issues/521
                                if [[ "${base_distro}" == "arch" ]]; then
                                    sys_packages+=(glibc)
                                fi
                                sys_packages+=(jq)
                            fi
                            sys_install "${sys_packages[@]}"
                        fi
                        echo "::endgroup::"
                        ;;
                    *) warn "cache-cargo-install-action requires jq and curl on non-Debian/Fedora/Arch/Alpine-based Linux" ;;
                esac
            fi
            ;;
        macos)
            if ! type -P jq &>/dev/null || ! type -P curl &>/dev/null; then
                warn "cache-cargo-install-action requires jq and curl on macOS"
            fi
            ;;
        windows)
            if ! type -P curl &>/dev/null; then
                warn "cache-cargo-install-action requires curl on Windows"
            fi
            # https://github.com/jqlang/jq/issues/1854
            jq_use_b=1
            jq="${install_action_dir}/jq/bin/jq.exe"
            if [[ ! -f "${jq}" ]]; then
                jq_version=$(jq --version || echo "")
                case "${jq_version}" in
                    jq-1.[7-9]* | jq-1.[1-9][0-9]*) jq='' ;;
                    *)
                        _tmp=$(jq <<<"{}" -r .a || echo "")
                        if [[ "${_tmp}" == "null" ]]; then
                            jq=''
                            jq_use_b=''
                        else
                            info "old jq (${jq_version}) has bug on Windows; downloading jq 1.7 (will not be added to PATH)"
                            mkdir -p "${install_action_dir}/jq/bin"
                            url='https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-windows-amd64.exe'
                            checksum='7451fbbf37feffb9bf262bd97c54f0da558c63f0748e64152dd87b0a07b6d6ab'
                            (
                                cd "${install_action_dir}/jq/bin"
                                download_and_checksum "${url}" "${checksum}"
                                mv tmp jq.exe
                            )
                            echo
                        fi
                        ;;
                esac
            fi
            ;;
        *) bail "unsupported host OS '${host_os}'" ;;
    esac
    call_jq() {
        # https://github.com/jqlang/jq/issues/1854
        if [[ -n "${jq_use_b}" ]]; then
            "${jq:-jq}" -b "$@"
        else
            "${jq:-jq}" "$@"
        fi
    }

    crate_info=$(retry curl --proto '=https' --tlsv1.2 -fsSL --retry 10 "https://crates.io/api/v1/crates/${tool}")
    case "${version}" in
        latest)
            version=$(call_jq <<<"${crate_info}" -r '.crate.max_stable_version')
            if [[ "${version}" == "null" ]]; then
                bail "no stable version found for ${tool}; if you want to install a pre-release version, please specify the full version"
            fi
            ;;
        *)
            if [[ ! "${version}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                bail "cache-cargo-install-action does not support non-semver version: '${version}'"
            fi
            # shellcheck disable=SC2207
            versions=($(call_jq <<<"${crate_info}" -r ".versions[] | select(.num | startswith(\"${version}.\")) | select(.yanked == false) | .num"))
            for v in ${versions[@]+"${versions[@]}"}; do
                if [[ ! "${v}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(\+[0-9A-Za-z\.-]+)?$ ]]; then
                    continue
                fi
                full_version="${v}"
                break
            done
            if [[ -z "${full_version:-}" ]]; then
                bail "no stable version  found for ${tool} that match with '${version}.*'; if you want to install a pre-release version, please specify the full version"
            fi
            version="${full_version}"
            ;;
    esac
fi

bin_dir="${RUNNER_TOOL_CACHE}/${tool}/bin"
echo "${bin_dir}" >>"${GITHUB_PATH}"

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
