#!/bin/bash

#set -ex
set -e

init_variables() {
VERSION=0.3
TEMPDIR=$(mktemp -d -t omni.XXXXXX)
url=https://localhost:9502
VERBOSE=0
SCRIPT=${0##*\/}
RCFILE=omni_deployment.ini
}

cleanup() {
  test -n "$TEMPDIR" && rm -rf "$TEMPDIR"
}

trap cleanup EXIT

display_help() {
cat <<EOF
USAGE: $SCRIPT -P <ProjectID> -B <DQBranch> -U <URL> -G <Git_Remote> -D <DQProject>
USAGE: $SCRIPT [-vVh]

Download the deployment bundle for Omni
<ProjectID> and update with the dq components
from dq branch <DQBranch>

    [default parameter]:
    -v - verbose output
    -V - return version
    -h - this help page

    Uses <Git_Remote> for accessing the DQ remote.
    Uses <URL> for downloading (default: https://localhost:9502 if not given).
    Uses <DQProject> for the DQ Project (usually shouldn't change).

Version: $VERSION
EOF
}

getVersion() {
cat <<EOF
$SCRIPT

Version: $VERSION
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

is_git_dir() {
  # is current directory a git working tree?
  git rev-parse --git-dir >/dev/null 2>&1
  return $?
}

determine_git_branch()
{
  # try to determine the current git branch
  # if it is not yet known
  if [[ -z "$DQBranch" && is_git_dir ]]; then
    DQBranch=$(git symbolic-ref --short HEAD)
  fi
}

debug_output() {
if [ "$VERBOSE" -eq 1 ]; then
cat<<EOF
$SCRIPT Parameters:

ProjectID:	$ProjectID
DQBranch:	$DQBranch
GITRemote:	$GITRemote
GITProject:	$GITProject
Deployment-URL:	$url
RCFile:		$RCFILE

Enabling debug mode
EOF

exit 2;
fi
}

source_ini_file() {
  if [ -f "$RCFILE" ]; then 
    if [ "$VERBOSE" -gt 0 ]; then
      echo "sourcing ini file"
    fi
    . "$RCFILE"
  fi
}


# Main Script
init_variables

# Needs to be in Main!
# Process commandline parameters
while getopts "vVhU:P:B:G:D:" ARGS
    do
        case ${ARGS} in
        U) url=${OPTARG} ;;
        P) ProjectID=${OPTARG} ;;
        B) DQBranch=${OPTARG} ;;
        G) GITRemote=${OPTARG} ;;
        D) GITProject=${OPTARG} ;;
        v) VERBOSE=1;;
        V) getVersion; exit 0 ;;
        h) display_help; exit 0 ;;
        *) display_help; exit 1 ;;
        esac
done

shift `expr ${OPTIND} - 1`

source_ini_file
determine_git_branch
debug_output

if [ -z "$ProjectID" -o  -z "$DQBranch" -o -z "$GITRemote" -o -z "$GITProject" ]; then
    display_help;
    exit 1;
fi


exit 1
download_and_process


# vim: set et tw=80 sw=0 sts=-1 ts=2 fo+=r :
