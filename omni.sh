#!/bin/bash

#set -ex
set -e

VERSION=0.2
TEMPDIR=$(mktemp -d -t omni.XXXXXX)
url=https://localhost:9502

cleanup() {
	test -n "$TEMPDIR" && rm -rf "$TEMPDIR"
}

trap cleanup EXIT

display_help() {
cat <<EOF
USAGE: ${0##*\/} -P <ProjectID> -B <DQBranch> -U <URL> -G <Git_Remote> -D <DQProject>

    Download the deployment bundle for Omni
		<ProjectID> and update with the dq components
		from dq branch <DQBranch>

		Uses <Git_Remote> for accessing the DQ remote.
		Uses <URL> for downloading (default: https://localhost:9502 if not given).
		Uses <DQProject> for the DQ Project (usually shouldn't change).

Version: $VERSION
EOF
}

getVersion() {
cat <<EOF
${0##*\/}

$VERSION
EOF
}

update_manifest() {
	sed -i \
		-e 's/^Created-By:.*/& - Omni Deployment Script/' \
		-e 's/^omnigen-release-number:.*/&.branch/' \
	META-INF/Manifest.mf
}

test_dq_branch() {
	git ls-remote -q --exit-code --heads "$GITRemote" "$DQBranch" >/dev/null || \
	(
		echo "DQ Branch \"$DQBranch\" does not exist!"
		exit 2;
	)
}

download_and_process() {
	test_dq_branch
	cd "$TEMPDIR"
	curl -sSk -o output_omni.html "${url}/generate?project_id=${ProjectID}"
	ZIP=$(sed -ne 's#.*<a href="\(.*\)">Download.*</a></div>$#\1#p' output_omni.html)
	curl -sSk -o omni_deployment.zip "${url}/$ZIP"
	cp omni_deployment.zip ~/Downloads
	unzip -q omni_deployment.zip
	update_manifest
	git clone --quiet --bare "${GITRemote}"  dqs
	DQProject=$(git --git-dir=dqs ls-tree  -r dev:Plans/ -d  --name-only  |head -1)
	git --git-dir=dqs archive --format=zip -o dq_archive.zip "${DQBranch}^{tree}" "Plans/${DQProject}"
	unzip -q dq_archive.zip
	cp -r "Plans/${DQProject}"/* server/mastering/
	rm -f omni_deployment.zip
	ZIP="omni_deployment_$(date +%Y%m%d.zip)"
	7z a -bb0 "$ZIP" META-INF/ server/ >/dev/null
	cp "$ZIP" ~/Downloads
	echo "Deployment_package $ZIP available at ~/Downloads"
}

# Process commandline parameters
while getopts "U:P:B:G:D:" ARGS
    do
        case ${ARGS} in
        U) url=${OPTARG} ;;
        P) ProjectID=${OPTARG} ;;
        B) DQBranch=${OPTARG} ;;
				G) GITRemote=${OPTARG} ;;
				D) GITProject=${OPTARG} ;;
        v) getVersion; exit 0 ;;
        h) display_help; exit 0 ;;
        *) display_help; exit 1 ;;
        esac
done

shift `expr ${OPTIND} - 1`

if [ -z "$ProjectID" -o  -z "$DQBranch" -o -z "$GITRemote" -o -z "$GITProject" ]; then
    display_help;
    exit 1;
fi

download_and_process
