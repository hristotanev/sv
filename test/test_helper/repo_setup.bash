#!/bin/bash

_repo_create() {
  cd $DIR && mkdir test-repo && cd test-repo
  git init >/dev/null
  git config init.defaultBranch master
}

_repo_init() {
  run sv.sh init
  _set_value_of_key "sv.yaml" "branch" "master"
  _set_value_of_key "sv.yaml" "version_provider" "npm"

  pnpm init >/dev/null
  _set_value_of_key "package.json" ".version" "0.0.1"

  echo "{ \"version\": \"0.0.0\" }" >version_file.json

  git add . >/dev/null
  git commit -m "initial commit" >/dev/null
}

_add_test_commits() {
  commit_types=(fix feat build chore ci docs style refactor perf test)
  for type in "${commit_types[@]}"; do
    echo "$type" >$type
    git add . >/dev/null
    git commit -m "$type!: commit message" >/dev/null
  done

  echo "breaking change 1" >breaking_change1
  git add . >/dev/null
  git commit -m "feat: commit message BREAKING CHANGE 1" >/dev/null

  echo "breaking change 2" >breaking_change2
  git add . >/dev/null
  git commit -m "feat: commit message BREAKING-CHANGE 2" >/dev/null

  echo "feat2" >feat2
  git add . >/dev/null
  git commit -m "feat: commit message" >/dev/null

  echo "fix2" >fix2
  git add . >/dev/null
  git commit -m "fix: commit message" >/dev/null
}

_repo_delete() {
  rm -rf $DIR/test-repo
}
