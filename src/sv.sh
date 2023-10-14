#!/bin/bash
set -e

help() {
  cat <<EOF
sv - Semantic Version (sv) bump tool

Usage: sv [OPTION]
       sv [COMMAND]

OPTIONS:
  -h, --help: show help

COMMANDS:
  init: creates default 'sv.yaml' configuration file in the current working directory
  bump: automatically increases the version, based on the commits

EOF
}

init() {
  if [[ -e ./sv.yaml ]]; then
    echo "sv.yaml already exists." >&2
    exit 1
  fi

  cat <<EOF >sv.yaml
# Set this to the branch used for releasing.
# Examples include "main", "master" and others.
branch: "<release branch>"

# For now the only supported provider is "npm".
version_provider: "<provider>"

# Files to update with the new version.
version_files: []
EOF
}

is_valid_semver() {
  [[ "$1" =~ ^[0-9]+.[0-9]+.[0-9]+$ ]] && echo -n 1 || echo -n 0
}

parse_semver() {
  IFS='.' read -ra semver <<<"$1"

  echo -n "${semver[@]}"
}

to_semver() {
  semver=(${@:1})

  major=${semver[0]}
  minor=${semver[1]}
  patch=${semver[2]}

  echo -n "$major.$minor.$patch"
}

get_value_of_key() {
  pipe_data=$(cat </dev/stdin)
  key=$1
  parser=$2

  value=$(echo -n "$pipe_data" | dasel -r $parser "$key")

  echo -n $(echo -n "$value" | tr -d '"')
}

set_value_of_key() {
  file=$1
  key=$2
  value=$3

  dasel put -f $file -v "$value" "$key"
  if [[ $? != 0 ]]; then
    exit 1
  fi
}

semver_cmp() {
  semver_a=($(parse_semver $1))
  semver_b=($(parse_semver $2))

  for ((i = 0; i < 3; i++)); do
    [[ ${semver_a[$i]} -lt ${semver_b[$i]} ]] && echo -n -1 && exit 0
    [[ ${semver_a[$i]} -gt ${semver_b[$i]} ]] && echo -n 1 && exit 0
  done

  echo -n 0
}

increase_version() {
  semver=($(parse_semver $1))
  message=$2

  if [[ "$message" =~ BREAKING(\ |-)CHANGE || "${message,,}" =~ ^(fix|feat|build|chore|ci|docs|style|refactor|perf|test)(\(.+\))?!: ]]; then
    semver[0]=$((${semver[0]} + 1))
    semver[1]=0
    semver[2]=0

    echo -n $(to_semver "${semver[@]}")
    exit 0
  fi

  if [[ "${message,,}" =~ ^feat(\(.+\))?: ]]; then
    semver[1]=$((${semver[1]} + 1))
    semver[2]=0

    echo -n $(to_semver "${semver[@]}")
    exit 0
  fi

  if [[ "${message,,}" =~ ^fix(\(.+\))?: ]]; then
    semver[2]=$((${semver[2]} + 1))

    echo -n $(to_semver "${semver[@]}")
    exit 0
  fi

  echo -n $(to_semver "${semver[@]}")
}

calculate_final_version() {
  semver=$1
  commits=(${@:2})

  for ((i = $((${#commits[@]} - 1)); i >= 0; i--)); do
    message=$(git log --format=%B "${commits[$i]}" -n 1)
    semver=$(increase_version "$semver" "$message")
  done

  echo -n $semver
}

check_package_versions() {
  commits=(${@:1})

  for hash in ${commits[@]}; do
    version=$(git show "$hash:$FILE_PATH" | get_value_of_key "$KEY_PATH" "$PARSER")

    if [[ $(is_valid_semver $version) == 0 ]]; then
      echo "Versions found to be in incorrect format." >&2
      exit 1
    fi
  done
}

find_first_commit_with() {
  latest_version=$1
  commits=(${@:2})

  start=-1
  end=${#commits[@]}
  while [[ $(($start + 1)) -lt $end ]]; do
    mid=$((($start + $end) / 2))

    hash=${commits[$mid]}
    version=$(git show "$hash:$FILE_PATH" | get_value_of_key "$KEY_PATH" "$PARSER")

    [[ $(semver_cmp "$version" "$latest_version") -ge 0 ]] && start=$mid || end=$mid
  done

  if [[ $start == 0 ]]; then
    echo "Version doesn't need to change." >&2
    exit 1
  fi

  echo -n $start
}

update_files_with_version() {
  final_version=$1

  dasel put -f $FILE_PATH -r $PARSER -v $final_version "$KEY_PATH"

  version_files=($(cat sv.yaml | get_value_of_key "version_files.all()" "yaml"))
  [[ $? != 0 || ${#version_files[@]} == 0 ]] && return

  for version_file in "${version_files[@]}"; do
    IFS=':' read -ra arr <<<"$version_file"
    file_path=${arr[0]}
    key_path=${arr[1]}

    set_value_of_key "$file_path" "$key_path" "$final_version"
  done
}

bump() {
  [[ ! -e ./sv.yaml ]] && echo "Run 'sv init' to create the 'sv.yaml' configuration." >&2 && exit 1

  branch=$(cat sv.yaml | get_value_of_key "branch" "yaml")
  commits=($(git rev-list "$branch" -1000))

  version_provider=$(cat sv.yaml | get_value_of_key "version_provider" "yaml")
  case "$version_provider" in
  npm)
    FILE_PATH="package.json"
    KEY_PATH=".version"
    PARSER="json"
    ;;
  *)
    echo "Version providers other than 'npm' are not supported yet." >&2
    exit 1
    ;;
  esac

  [[ ! -e $FILE_PATH ]] && echo "'$FILE_PATH' doesn't exist on '$branch'" >&2 && exit 1

  check_package_versions "${commits[@]}"

  latest_version=$(git show "$branch:$FILE_PATH" | get_value_of_key "$KEY_PATH" "$PARSER")
  start=$(find_first_commit_with "$latest_version" "${commits[@]}")
  final_version=$(calculate_final_version "$latest_version" "${commits[@]:0:$start}")

  echo "bump: $latest_version → $final_version"
  update_files_with_version "$final_version"
  echo "Done!"
}

case "$1" in
init)
  init
  ;;
bump)
  bump
  ;;
* | -h | --help)
  help
  ;;
esac
