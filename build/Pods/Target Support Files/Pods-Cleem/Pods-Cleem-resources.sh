#!/bin/sh
set -e
set -u
set -o pipefail

function on_error {
  echo "$(realpath -q "${0}"):$1: error: Unexpected failure"
}
trap 'on_error $LINENO' ERR

# Перенаправляю временные файлы в безопасную директорию
RESOURCES_TO_COPY="/tmp/cleem_tmp/resources-to-copy-Cleem.txt"
touch "$RESOURCES_TO_COPY" || true

RESOURCES_TO_COPY_TEMP="$RESOURCES_TO_COPY"

install_resource() {
  if [[ "$1" = /* ]] ; then
    RESOURCE_PATH="$1"
  else
    RESOURCE_PATH="${PODS_ROOT}/$1"
  fi
  if [[ ! -e "$RESOURCE_PATH" ]] ; then
    cat << EOM
error: Resource "$RESOURCE_PATH" not found. Run 'pod install' to update the copy resources script.
EOM
    exit 1
  fi
  # ... оставить остальной код без изменений ...
}

mkdir -p "${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"

# ... оставить остальной код без изменений ... 