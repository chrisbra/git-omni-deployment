#!/bin/bash

set -eu
trap cleanup EXIT
init_variables() { #{{{2
VERSION=0.4
url=https://localhost:9502
VERBOSE=0
SCRIPT=${0##*\/}
RCFILE=omni_deployment.ini
TEMPDIR=$(mktemp -d -t omni.XXXXXX)
}
cleanup() { #{{{2
  test -n "$TEMPDIR" && rm -rf "$TEMPDIR"
}
display_help() { #{{{2
cat <<EOF
USAGE: $SCRIPT -P <ProjectID> -B <DQBranch> -U <URL> -G <Git_Remote> -D <DQProject>
USAGE: $SCRIPT [-v<nr>Vh?]

Download the deployment bundle for Omni
<ProjectID> and update with the dq components
from dq branch <DQBranch>

    [default parameter]:
    -v<nr>	- verbose output (<nr> is verbose level, higher the more verbose)
    -V		- return version
    -h		- this help page
    -?		- this help page

    Uses <Git_Remote> for accessing the DQ remote.
    Uses <URL> for downloading (default: https://localhost:9502 if not given).
    Uses <DQProject> for the DQ Project (usually shouldn't change).

Version: $VERSION
EOF
}
getVersion() { #{{{2
cat <<EOF
$SCRIPT

Version: $VERSION
EOF
}
debug_output() { #{{{2
if [ "$VERBOSE" -ge 1 ]; then
cat<<EOF
$SCRIPT Parameters:

ProjectID:	$ProjectID
DQBranch:	$DQBranch
GITRemote:	$GITRemote
DQProject:	$GITProject
Deployment-URL:	$url

EOF
fi

if [ "$VERBOSE" -gt 1 ]; then
cat<<EOF
RCFile:		$RCFILE
ZIP:		$ZIP
ZIPCMD:		$zipcmd
curl:		$curl
git:		$git
unzip:		$unzip

Enabling debug mode
EOF

fi
}
update_manifest() { #{{{2
  echo_output "Updating Manifest"
  sed -i \
    -e 's/^Created-By:.*/& - Omni Deployment Script/' \
    -e "s/^omnigen-release-number:.*/&.dqbranch-${DQBranch##*/}/" \
  META-INF/Manifest.mf
}
test_dq_branch() { #{{{2
  echo_output "Checking remote branch $DQBranch for $GITRemote"
  git ls-remote -q --exit-code --heads "$GITRemote" "$DQBranch" >/dev/null || \
  (
    errorExit "DQ Branch \"$DQBranch\" does not exist!"
  )
}
download_and_process() { #{{{2
  local lurl="${url}/generate?project_id=${ProjectID}"
  OPWD="$PWD"
  cd "$TEMPDIR"

  echo_output "Calling Deployment-API: $lurl"

  curl -sSk -o output_omni.html "$lurl"
  ZIPR=$(sed -ne 's#.*<a href="\(.*\)">Download.*</a></div>$#\1#p' output_omni.html)

  lurl="${url}/${ZIPR}"
  echo_output "Downloading Deployment Zip $lurl"
  ZIPFILE="${ZIPR##*/}.zip"
  curl -sSk -o "$ZIPFILE" "$lurl"
  # Enable to be able to compare the original and new zip files
  # cp "$ZIPFILE" $OPWD/${ZIPFILE%%.zip}_backup.zip
  unzip -q "$ZIPFILE"
  rm -f "$ZIPFILE"

  update_manifest

  echo_output "Cloning DQS Repository $GITRemote"
  git clone --quiet --bare "${GITRemote}"  dqs
  # DQProject=$(git --git-dir=dqs ls-tree  -r dev:Plans/ -d  --name-only  |head -1)
  git --git-dir=dqs archive --format=zip -o dq_archive.zip "${DQBranch}^{tree}" "Plans/${GITProject}"

  echo_output "Updating Deployment Zipfile"
  unzip -q dq_archive.zip
  cp -r "Plans/${GITProject}"/* server/mastering/
  zip_contents "$ZIPFILE" META-INF/ server/

  echo_output "Copying resulting Deployment package"
# Enable to be able to compare original and new version
# cp "$ZIPFILE" ~/Downloads
  cp "$ZIPFILE" "$OPWD"

  echo "Deployment_package $ZIPFILE available at $OPWD"
}
zip_contents() { #{{{2
  ZIPFILE=$1
  shift
  if [[ "$ZIP" == "7z" && -x "$zipcmd" ]]; then
    7z a -bb0 "$ZIPFILE" $* >/dev/null
  elif [[ "$ZIP" == "zip" && -x "$zipcmd" ]]; then
    zip -q -r "$ZIPFILE" $*
  else
    errorExit "No Zip command found"
  fi
}
is_git_dir() { #{{{2
  # is current directory a git working tree?
  git rev-parse --git-dir >/dev/null 2>&1
  return $?
}
determine_current_git_branch() {  #{{{2
  # try to determine the current git branch
  # if it is not yet known
  if [[ "X" == "${DQBranch:-X}" && is_git_dir ]]; then
    echo_output "Determining git branch from current working directory $PWD"
    DQBranch=$(git symbolic-ref --short HEAD)
  fi
}
source_ini_file() { #{{{2
  if [ -f "$RCFILE" ]; then
    if [ "$VERBOSE" -gt 0 ]; then
      echo "sourcing ini file"
    fi
    . "$RCFILE"
  fi
}
errorExit(){ #{{{2
  echo "$*" >&2
  exit 3
}
check_requirements() { #{{{2
  # Curl
  curl=$(which curl 2>/dev/null) || errorExit "Curl not found!" ;
  # Git
  git=$(which git 2>/dev/null) || errorExit "git not found!" ;
  # Zip
  { zipcmd=$(which 7z 2>/dev/null) || \
    zipcmd=$(which zip 2>/dev/null); } || errorExit "Zip not found!" ;
  ZIP=${zipcmd##*/}
  # unzip
  unzip=$(which unzip 2>/dev/null) || errorExit "unzip not found!" ;
}
echo_output() { #{{{2
  if [ "$VERBOSE" -gt 0 ]; then
    echo $*
  fi
}
# Main Script #{{{1
init_variables

# Needs to be in Main!
# Process commandline parameters
while getopts "?v:VhU:P:B:G:D:" ARGS
    do
        case ${ARGS} in
        U) url=${OPTARG} ;;
        P) ProjectID=${OPTARG} ;;
        B) DQBranch=${OPTARG} ;;
        G) GITRemote=${OPTARG} ;;
        D) GITProject=${OPTARG} ;;
        v) VERBOSE=${OPTARG:-1};;
        V) getVersion; exit 0 ;;
        h) display_help; exit 0 ;;
        *) display_help; exit 1 ;;
        esac
done

shift `expr ${OPTIND} - 1`

check_requirements
source_ini_file
determine_current_git_branch
debug_output

if [ -z "$ProjectID" -o  -z "$DQBranch" -o -z "$GITRemote" -o -z "$GITProject" ]; then
  echo "Missing Parameters!"
  display_help;
  exit 1;
fi

if [ "$DQBranch" = "master" ]; then
  echo "DQ Branch is master, nothing to do."
  exit 0;
fi

test_dq_branch
download_and_process

# vim: set et tw=80 sw=0 sts=-1 ts=2 fo+=r :
