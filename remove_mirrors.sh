#/bin/bash

remove_mirrors() {
    commands=(publish snapshot mirror)

    for c in ${commands[@]}; do
	for i in $(aptly $c list --raw); do
	    aptly $c drop $i
	done
    done
}

remove_mirrors
