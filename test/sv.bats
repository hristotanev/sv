setup() {
  load 'test_helper/bats-support/load'
  load 'test_helper/bats-assert/load'
  load 'test_helper/repo_setup'
  load 'test_helper/helpers'

  DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  PATH="$DIR/../src:$PATH"
  SKIP_TESTS=0

  _repo_create

  cd $DIR/test-repo
}

teardown() {
  _repo_delete
}

@test "it can run sv" {
  [[ $SKIP_TESTS == 1 ]] && skip

  run sv.sh -h
  assert_success
}

@test "'sv init' creates sv.yaml successfully" {
  [[ $SKIP_TESTS == 1 ]] && skip

  run sv.sh init
  [[ ! -e ./sv.yaml ]] && exit 1

  assert_success
}

@test "'sv init' fails if sv.yaml already exists" {
  [[ $SKIP_TESTS == 1 ]] && skip

  run sv.sh init
  run sv.sh init

  assert_failure
  assert_output "sv.yaml already exists."
}

@test "'sv bump' fails when sv.yaml file is missing" {
  [[ $SKIP_TESTS == 1 ]] && skip

  run sv.sh bump

  assert_failure
  assert_output "Run 'sv init' to create the 'sv.yaml' configuration."
}

@test "'sv bump' fails if release branch is not specified" {
  [[ $SKIP_TESTS == 1 ]] && skip
  
  run sv.sh init

  git add . >/dev/null
  git commit -m "initial commit" >/dev/null

  run sv.sh bump

  assert_failure
}

@test "'sv bump' fails if release branch is missing" {
  [[ $SKIP_TESTS == 1 ]] && skip

  run sv.sh init

  dasel delete -f sv.yaml 'branch'
  git add . >/dev/null
  git commit -m "remove branch" >/dev/null

  run sv.sh bump

  assert_failure
}

@test "'sv bump' fails if version provider is not specified" {
  [[ $SKIP_TESTS == 1 ]] && skip

  _repo_init

  _set_value_of_key "sv.yaml" "version_provider" "<provider>"

  git add . >/dev/null
  git commit -m "set version_provider to an invalid value" >/dev/null

  run sv.sh bump

  assert_failure
  assert_output "Version providers other than 'npm' are not supported yet."
}

@test "'sv bump' fails if version provider is missing" {
  [[ $SKIP_TESTS == 1 ]] && skip

  _repo_init

  dasel delete -f sv.yaml 'version_provider'
  git add . >/dev/null
  git commit -m "remove version_provider" >/dev/null

  run sv.sh bump

  assert_failure
}

@test "'sv bump' fails if package.json is missing" {
  [[ $SKIP_TESTS == 1 ]] && skip

  _repo_init

  rm -rf package.json
  git add . >/dev/null
  git commit -m "remove package.json" >/dev/null

  run sv.sh bump

  assert_failure
  assert_output "'package.json' doesn't exist on 'master'"
}

@test "'sv bump' fails if latest package.json version is invalid" {
  [[ $SKIP_TESTS == 1 ]] && skip

  _repo_init

  _set_value_of_key "package.json" ".version" "0.0.1rc1"

  git add . >/dev/null
  git commit -m "set package.json version to an invalid value" >/dev/null

  run sv.sh bump

  assert_failure
  assert_output "Versions found to be in incorrect format."
}

@test "'sv bump' fails if latest package.json version is missing" {
  [[ $SKIP_TESTS == 1 ]] && skip

  _repo_init

  dasel delete -f package.json '.version'

  git add . >/dev/null
  git commit -m "remove package.json version" >/dev/null

  run sv.sh bump

  assert_failure
}

@test "'sv bump' doesn't update the version when it hasn't changed" {
  [[ $SKIP_TESTS == 1 ]] && skip

  _repo_init

  run sv.sh bump

  assert_failure
  assert_output "Version doesn't need to change."
}

@test "'sv bump' updates the package version correctly" {
  [[ $SKIP_TESTS == 1 ]] && skip

  _repo_init
  _add_test_commits

  run sv.sh bump

  assert_success
  assert_output -p "bump: 0.0.1 → 12.1.1"
  assert_output -p "Done!"
}

@test "'sv bump' doesn't update version_files if property missing from sv.yaml" {
  [[ $SKIP_TESTS == 1 ]] && skip

  _repo_init

  dasel delete -f sv.yaml 'version_files'
  git add . >/dev/null
  git commit -m "remove version_files" >/dev/null

  _add_test_commits

  run sv.sh bump

  assert_success
  assert_output -p "bump: 0.0.1 → 12.1.1"
  assert_output -p "Done!"
}

@test "'sv bump' updates the package version correctly and updates version files" {
  [[ $SKIP_TESTS == 1 ]] && skip

  _repo_init

  _set_value_of_key "sv.yaml" "version_files.append()" "version_file.json:.version"
  git add . >/dev/null
  git commit -m "initialise version_files" >/dev/null

  _add_test_commits

  run sv.sh bump

  assert_success
  assert_output -p "bump: 0.0.1 → 12.1.1"
  assert_output -p "Done!"

  assert_equal $(_get_value_of_key "package.json" ".version") "12.1.1"
  assert_equal $(_get_value_of_key "version_file.json" ".version") "12.1.1"
}
