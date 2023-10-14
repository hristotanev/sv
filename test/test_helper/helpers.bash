#!/bin/bash

_get_value_of_key() {
  file=$1
  key=$2

  dasel -f $file -r "${file##*.}" "$key" | tr -d '"'
}

_set_value_of_key() {
  file=$1
  key=$2
  value=$3

  dasel put -f $file -v "$value" "$key"
}
