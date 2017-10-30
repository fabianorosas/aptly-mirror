#/bin/bash
# Usage:
# To create and serve an empty mirror in localhost:
#     ./update_mirror.sh
# then add to sources.list:
#
# deb [trusted=true] http://localhost:8080 xenial main universe
# deb [trusted=true] http://localhost:8080 xenial-updates main universe
# deb [trusted=true] http://localhost:8080 xenial-security main universe
#
# To update the mirror with new packages:
#     ./update_mirror.sh pkg1 pkg2 pkg3
#

set -u

PACKAGES=$@
MIRRORS=(xenial xenial-updates xenial-security)
ARCHS=ppc64el # comma separated list


create_mirrors() {
    for mirror_name in ${MIRRORS[@]}; do
	snapshot_name=$mirror_name-current

	aptly mirror create -filter="adduser" -filter-with-deps=true -architectures="$ARCHS" -ignore-signatures $mirror_name \
	      http://ports.ubuntu.com/ubuntu-ports $mirror_name main universe
	if [ $? != 0 ]; then
	    echo "Mirror already exists"
	    exit 1
	fi
	aptly mirror update $mirror_name
	aptly snapshot create $snapshot_name from mirror $mirror_name
	aptly publish snapshot -skip-signing -architectures="$ARCHS" -distribution=$mirror_name $snapshot_name
    done
    aptly serve &
}

update_mirrors() {
    packages=($@)

    for mirror_name in ${MIRRORS[@]}; do
	current_filter=$(aptly mirror show $mirror_name | awk '/Filter:/{$1=""; print $0}')
	new_filter="$current_filter $(printf '| %s' "${packages[@]}")"
	aptly mirror edit -filter="$new_filter" -architectures="$ARCHS" $mirror_name
	aptly mirror update $mirror_name

	snapshot_tmp=$mirror_name-tmp
	snapshot_curr=$mirror_name-current

	aptly snapshot create $snapshot_tmp from mirror $mirror_name
	aptly publish -skip-signing switch $mirror_name $snapshot_tmp
	aptly snapshot drop $snapshot_curr
	aptly snapshot rename $snapshot_tmp $snapshot_curr
    done
}

[ $# = 0 ] && create_mirrors
[ $# -gt 0 ] && update_mirrors $@
