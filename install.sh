#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Do not set -E as busybox 3.15 and older don't support it.
set -Ceuo pipefail
IFS=$'\n\t'

case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN* | Windows_NT)
    home="${HOME:-}"
    if [[ -z "${home}" ]]; then
      # https://github.com/IBM/actionspz/issues/30
      home=$(realpath ~)
      export HOME="${home}"
    fi
    if [[ "${home}" == "/home/"* ]]; then
      if [[ -d "${home/\/home\///c/Users/}" ]]; then
        # MSYS2 https://github.com/taiki-e/install-action/pull/518#issuecomment-2160736760
        home="${home/\/home\///c/Users/}"
      elif [[ -d "${home/\/home\///cygdrive/c/Users/}" ]]; then
        # Cygwin https://github.com/taiki-e/install-action/issues/224#issuecomment-1720196288
        home="${home/\/home\///cygdrive/c/Users/}"
      else
        warn "\$HOME starting /home/ (${home}) on Windows bash is usually fake path, this may cause checkout issue"
      fi
    fi
    mkdir -p -- "${home}/.cache-cargo-install-action"
    # See action.yml.
    touch -- "${home}/.cache-cargo-install-action/init"
    ;;
esac

export CARGO_NET_RETRY=10

IFS=' '
# shellcheck disable=SC2086
set -- ${INPUT_ARGS}
IFS=$'\n\t'

(
  set -x
  cargo install -f "${INPUT_TOOL}" --root "${RUNNER_TOOL_CACHE}/${INPUT_TOOL}" "$@"
)
