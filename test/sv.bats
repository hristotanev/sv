setup_file() {
  DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
  PATH="$DIR/../src:$PATH"
}

setup() {
  load 'test_helper/bats-support/load'
  load 'test_helper/bats-assert/load'
}


@test "can run tool" {
  run sv.sh -h
  assert_success
}
