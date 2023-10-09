#!/bin/bash
set -e

FILE_PATH="package.json"
KEY_PATH=".version"

help() {
  cat <<EOF
sv - Semantic Version Bump tool

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
  cat <<EOF >sv.yaml
# Specify the main branch which is going to be used to release from.
# Most commonly this is either 'master' or 'main'.
# main_branch: "master"

# version: "x.y.z"

# version_files:
#   - "package.json:.version"
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

get_version_from() {
  position=$1
  file_path=$2
  key_path=$3

  semver=$(git show "$position:$file_path" | dasel -r "${file_path##*.}" "$key_path")
  [[ $? != 0 ]] && exit 1

  semver=$(echo -n "$semver" | tr -d '"')
  echo -n $semver
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

  if [[ "$message" =~ BREAKING(\ |-)CHANGE || "${message,,}" =~ ^(fix|feat)(\(.+\))?!: ]]; then
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

bump() {
  commits=($(git rev-list "master" -1000))
  latest_version=$(get_version_from "master" "sv.yaml" "version")
  [[ $? != 0 ]] && exit 1

  start=-1
  end=${#commits[@]}
  while [[ $(($start + 1)) -lt $end ]]; do
    mid=$((($start + $end) / 2))

    hash=${commits[$mid]}
    version=$(get_version_from $hash $FILE_PATH $KEY_PATH)

    [[ $(semver_cmp "$version" "$latest_version") -ge 0 ]] && start=$mid || end=$mid
  done

  [[ $start == 0 ]] && echo "Version hasn't changed." && exit 1

  final_version=$(calculate_final_version "$latest_version" "${commits[@]:0:$start}")
  echo "bump: $latest_version → $final_version"

  dasel put -f $FILE_PATH -r json -v $final_version "$KEY_PATH"
  echo "Done!"
}

case "$1" in
init)
  init
  ;;
bump)
  bump
  ;;
-h | --help)
  help
  ;;
*)
  echo "Unrecognised command. Run 'sv --help' to see available options and commands." && exit 1
  ;;
esac
