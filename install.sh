#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -CeEuo pipefail
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

args=(
  -f "${INPUT_TOOL}"
  --root "${RUNNER_TOOL_CACHE}/${INPUT_TOOL}"
)
if [[ -n "${INPUT_LOCKED}" ]]; then
  args+=("${INPUT_LOCKED}")
fi
if [[ -n "${INPUT_FEATURES_FLAG}" ]]; then
  args+=("${INPUT_FEATURES_FLAG}")
fi
if [[ -n "${INPUT_NO_DEFAULT_FEATURES_FLAG}" ]]; then
  args+=("${INPUT_NO_DEFAULT_FEATURES_FLAG}")
fi
if [[ -n "${INPUT_ALL_FEATURES_FLAG}" ]]; then
  args+=("${INPUT_ALL_FEATURES_FLAG}")
fi
if [[ -n "${INPUT_GIT}" ]]; then
  args+=(--git "${INPUT_GIT}")
  if [[ -n "${INPUT_TAG}" ]]; then
    args+=(--tag "${INPUT_TAG}")
  else
    args+=(--rev "${INPUT_REV}")
  fi
else
  args+=(--version "${INPUT_VERSION}")
fi

(
  set -x
  cargo install "${args[@]}"
)
