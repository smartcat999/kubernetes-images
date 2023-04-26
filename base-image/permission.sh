#!/bin/bash


# shellcheck disable=SC2113
function change_permission {
  crt=$(find $1 ! -perm 600 -name "*.crt" -o ! -perm 600 -name "*.pem" 2>/dev/null)
  # shellcheck disable=SC2068
  for elem in ${crt[@]}; do
    chmod 600 $elem
  done;

  conf=$(find $1 ! -perm 640 -name "*.conf" 2>/dev/null)
  # shellcheck disable=SC2068
    for elem in ${conf[@]}; do
      chmod 640 $elem
    done;
}

change_permission /etc
change_permission /usr