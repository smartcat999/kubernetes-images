#!/bin/sh


# shellcheck disable=SC2113
function change_permission {
  etc=$(find $1 ! -perm 600 -name "*.crt" -o ! -perm 600 -name "*.pem" -o ! -perm 600 -name "*.conf" 2>/dev/null)
  # shellcheck disable=SC2068
  for elem in ${etc[@]}; do
    chmod 600 $elem
  done;
}

change_permission /etc
change_permission /usr