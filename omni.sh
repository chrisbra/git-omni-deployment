#!/bin/bash

set -euo pipefail
trap cleanup EXIT ERR
init_variables() { #{{{2
  # Variables here are just the default/fallback.
  # They should be set via the configuration file or via parameter to the script.
  VERSION=0.6
  url=https://localhost:9502
  EMF_API_URL=http://localhost:9516/com.iwaysoftware.omni.designer.repositoryservice
  VERBOSE=0
  SCRIPT=${0##*\/}
  RCFILE=omni_deployment.ini
  CURL_PARAM="-Ssk"
  TEMPDIR=$(mktemp -d -t omni.XXXXXX)
  ProjectBundle=n
  AUTH=$(printf "super:super"|base64)
}
cleanup() { #{{{2
  test -n "$TEMPDIR" && rm -rf "$TEMPDIR"
}
display_help() { #{{{2
cat <<EOF
USAGE: $SCRIPT -p -P <ProjectID> -B <DQBranch> -U <URL> -G <Git_Remote> -D <DQProject>
USAGE: $SCRIPT [-v<nr>Vh?]

Create Project and Deployment-Bundle, downloads the deployment bundle for Omni
<ProjectID> and update with the dq components from dq branch <DQBranch>

    [default parameter]:
    -p		- create Project Bundle as well
    -E		- Specify EMF Store API (should look like this:
    http://localhost:9516/com.iwaysoftware.omni.designer.repositoryservice/)
    -U		- Specify URL for the Deployment Console
    -P		- Specify ProjectID
    -B		- Specify DQ Branch (git branch name)
    -G		- Git Repository URL
    -D		- Project Name in the Git repository
    -d		- Skip verification of git DQ branch
    -v<nr>	- verbose output (<nr> is verbose level, higher the more verbose)
    -V		- return version
    -h		- this help page
    -?		- this help page

    Uses <URL> for downloading (default: https://localhost:9502 if not given).
    Uses <DQProject> for the DQ Project (usually shouldn't change).

    The resulting deployment bundle will be stored in the current directory.

Version: $VERSION
EOF
}
getVersion() { #{{{2
  # Output Script Version
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
EMF_API_URL:	$EMF_API_URL

EOF
fi

if [ "$VERBOSE" -gt 1 ]; then
cat<<EOF
Enabling debug mode
RCFile:		$RCFILE
ZIP:		$ZIP
ZIPCMD:		$zipcmd
curl:		$curl
curl_param:	$CURL_PARAM
git:		$git
unzip:		$unzip
PWD:		$PWD
TEMPDIR:	$TEMPDIR
VERIFY_DQ_BRANCH: ${VERIFY_DQ_BRANCH:-y}
EOF

fi
}
update_manifest() { #{{{2
  echo_output 1 "Updating Manifest"
  sed -i \
    -e 's/^Created-By:.*/& - Omni Deployment Script/' \
    -e "s/^omnigen-release-number:.*/&.dqbranch-${DQBranch##*/}/" \
  META-INF/Manifest.mf
}
test_dq_branch() { #{{{2
  if [ "${VERIFY_DQ_BRANCH:-}" = "n" ]; then
    echo_output 1 "Skipping verfication of DQ Branch in remote repository"
    return
  fi

  # assume master branch always exists
  if [ "$DQBranch" = "master" ]; then
    return
  fi
  echo_output 1 "Checking remote branch $DQBranch for $GITRemote"
  git -c credential.helper=manager ls-remote -q --exit-code --heads "$GITRemote" "$DQBranch" >/dev/null || \
  (
    errorExit "DQ Branch \"$DQBranch\" or Repository does not exist! (or authentication error). Errorcode: $?"
  )
}
download_and_process() { #{{{2
  local lurl="${url}/generate?project_id=${ProjectID}"
  OPWD="$PWD"
  cd "$TEMPDIR"

  echo_output 1 "Calling Deployment-API: $lurl"

  curl $CURL_PARAM -o output_omni.html "$lurl"
  ZIPR=$(sed -ne 's#.*<a href="\(.*\)">Download.*</a></div>$#\1#p' output_omni.html)

  lurl="${url}/${ZIPR}"
  echo_output 1 "Downloading Deployment Zip $lurl"
  ZIPFILE="${ZIPR##*/}.zip"
  curl $CURL_PARAM -o "$ZIPFILE" "$lurl"
  # Enable to be able to compare the original and new zip files
  # cp "$ZIPFILE" $OPWD/${ZIPFILE%%.zip}_backup.zip
  unzip -q "$ZIPFILE"
  rm -f "$ZIPFILE"

  update_manifest

  if [ "DQBranch" != "master" ]; then
    echo_output 1 "Modifying Deployment package with DQ content from $DQBranch"
    if [ "$GITRemote" = "${GITOrigin:-}" -a -n "${GITDIR:-}" ]; then
      echo_output 1 "Creating DQS Archive from $GITRemote and $DQBranch"
      git --git-dir="$GITDIR" archive --format=zip -o dq_archive.zip "${DQBranch}^{tree}" "Plans/${GITProject}"
    else
      echo_output 1 "Cloning DQS Repository $GITRemote"
      git clone --quiet --bare "${GITRemote}"  dqs
      # DQProject=$(git --git-dir=dqs ls-tree  -r dev:Plans/ -d  --name-only  |head -1)
      echo_output 1 "Creating DQS Archive from $GITRemote and $DQBranch"
      git --git-dir=dqs archive --format=zip -o dq_archive.zip "${DQBranch}^{tree}" "Plans/${GITProject}"
    fi

    echo_output 1 "Updating Deployment Zipfile"
    unzip -q dq_archive.zip
    cp -r "Plans/${GITProject}"/* server/mastering/
  fi

  zip_contents "$ZIPFILE" META-INF/ server/

  echo_output 1 "Copying resulting Deployment package"
# Enable to be able to compare original and new version
# cp "$ZIPFILE" ~/Downloads
  cp "$ZIPFILE" "$OPWD"

  echo "Deployment_package $ZIPFILE available at $OPWD"
}
zip_contents() { #{{{2
  # $1: Archive Name
  # following arguments the directories to process
  #
  # needs 7z or zip
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
  GITDIR=$(git rev-parse --git-dir 2>&1) &&
  GITOrigin=$(git config remote.origin.url)

  if [ "$GITDIR" == '.git' ]; then
    GITDIR="${PWD}/${GITDIR}"
  fi
}
determine_current_git_branch() {  #{{{2
  # try to determine the current git branch
  # if it is not yet known
  if [[ -z "${DQBranch:-}" && -n "${GITDIR:-}" ]]; then
    echo_output 1 "Determining git branch from current working directory $PWD"
    DQBranch=$(git symbolic-ref --short HEAD 2>/dev/null) || true
  fi
}
source_ini_file() { #{{{2
  if [ -f "${PWD}/${RCFILE}" ]; then
    echo_output 0 "sourcing ini file ${PWD}/${RCFILE}"
    . "${PWD}/${RCFILE}"
  fi
}
errorExit(){ #{{{2
  echo "$*" >&2
  exit 3
}
check_requirements() { #{{{2
  # Check that required Commands are available
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
  # sed
  sed=$(which sed >/dev/null) || errorExit "sed not found!" ;
}
echo_output() { #{{{2
  local level=$1
  shift
  if [ "$VERBOSE" -ge "$level" ]; then
    echo "$*"
  fi
}
get_emf_version() { #{{{2
  if [ -z "${EMFBranch:-}" ]; then
    EMFBranch=$DQBranch
  fi
  # if DQSBRanch is master, use trunk (which is the master trunk in EMF Store)
  if [ "${EMFBranch}" = 'master' ]; then
    EMFBranch='trunk'
  fi
  # Replace '/' by '_'
  EMFBranch=${EMFBranch//\//_}
  echo_output 1 "Calling API to determine EMF Version: \
  ${EMF_API_URL}/emfstore/projects/${ProjectID}/${EMFBranch}/version"
  local RETURN_CODE=$(curl $CURL_PARAM -o /dev/null \
    -I -w "%{http_code}" \
    -X GET \
    --header 'Accept: application/json' \
    --header "Authorization: Basic $AUTH" \
    "${EMF_API_URL}/emfstore/projects/${ProjectID}/${EMFBranch}/version")
  if [ "$RETURN_CODE" != "200" ]; then
    errorExit "Unable to determine EMF Branch Version: Return code $RETURN_CODE"
  fi
  EMFVERSION=$(curl $CURL_PARAM \
    -X GET \
    --header 'Accept: application/json' \
    --header "Authorization: Basic $AUTH" \
      "${EMF_API_URL}/emfstore/projects/${ProjectID}/${EMFBranch}/version" | \
      sed -ne 's/^{"result":\([0-9]\+\)}/\1/p')
  echo_output 1 "EMF Version: $EMFVERSION"
}
get_project_release_numbers() { #{{{2

  echo_output 1 "Calling API to determine Project Version numbers: \
  ${EMF_API_URL}/projectbundle/releasebundle/${ProjectID}"
  local RETURN_CODE=$(curl $CURL_PARAM -o /dev/null \
    -I -w "%{http_code}" \
    -X GET \
    --header 'Accept: application/xml' \
    --header "Authorization: Basic $AUTH" \
    "${EMF_API_URL}/projectbundle/releasenumber/${ProjectID}")
  if [ "$RETURN_CODE" != "200" ]; then
    errorExit "Unable to determine relase number from EMF Project: Return code $RETURN_CODE"
  fi
  # ugly: reformat the version numbers, to shell code, and eval it
  eval $(curl $CURL_PARAM \
    -X GET \
    --header 'Accept: application/xml' \
    --header "Authorization: Basic $AUTH" \
    "${EMF_API_URL}/projectbundle/releasenumber/${ProjectID}" | \
    sed -e 's/</\n</g' | \
    sed -e 's/.*developmentStage>\(.\+\)$/DevelopmentStage="\1"/' \
    -e 's/.*developmentStageNumber>\(.\+\)$/DevelopmentStageNumber="\1"/' \
    -e 's/.*versionFirstNumber>\(.\+\)$/VersionFirstNumber="\1"/' \
    -e 's/.*versionSecondNumber>\(.\+\)$/VersionSecondNumber="\1"/' \
    -e 's/.*versionThirdNumber>\(.\+\)$/VersionThirdNumber="\1"/' \
    -e '/^<.*/d')
    echo_output 2 "Current Release Numbers:"
    echo_output 2 "DevelopmentStage:	$DevelopmentStage"
    echo_output 2 "DevelopmentStageNumber:	$DevelopmentStageNumber"
    echo_output 2 "VersionFirstNumber:	$VersionFirstNumber"
    echo_output 2 "VersionSecondNumber:	$VersionSecondNumber"
    echo_output 2 "VersionThirdNumber:	$VersionThirdNumber"
}
increment_release_numbers() { #{{{2
  echo_output 1 "Increment Release Numbers"
  if [ "$DevelopmentStageNumber" -ge 99 ]; then
    DevelopmentStageNumber=0
    VersionThirdNumber=$((${VersionThirdNumber} + 1))
  else
    DevelopmentStageNumber=$((${DevelopmentStageNumber} + 1))
  fi
  if [ "$VersionThirdNumber" -ge 99 ]; then
    VersionThirdNumber=0;
    VersionSecondNumber=$((${VersionSecondNumber} + 1))
  fi
  if [ "$VersionSecondNumber" -ge 99 ]; then
    VersionSecondNumber=0;
    VersionFirstNumber=$((${VersionFirstNumber} + 1))
  fi
    echo_output 2 "New Release Numbers:"
    echo_output 2 "DevelopmentStage:	$DevelopmentStage"
    echo_output 2 "DevelopmentStageNumber:	$DevelopmentStageNumber"
    echo_output 2 "VersionFirstNumber:	$VersionFirstNumber"
    echo_output 2 "VersionSecondNumber:	$VersionSecondNumber"
    echo_output 2 "VersionThirdNumber:	$VersionThirdNumber"
}
create_project_bundle() { #{{{2
  get_emf_version
  get_project_release_numbers
  increment_release_numbers
  # Create Input Document for the Project Creation
  # contains all the required parameters to create the project bundle
  # (mostly version numbers)
  XML=$(cat <<EOF
<?xml version="1.0"?>
<projectBundleRequestDTO>
  <projectId>${ProjectID}</projectId>
  <releaseNotes>New Release per API</releaseNotes>
  <releaseNumber>
    <developmentStage>${DevelopmentStage}</developmentStage>
    <developmentStageNumber>${DevelopmentStageNumber}</developmentStageNumber>
    <versionFirstNumber>${VersionFirstNumber}</versionFirstNumber>
    <versionSecondNumber>${VersionSecondNumber}</versionSecondNumber>
    <versionThirdNumber>${VersionThirdNumber}</versionThirdNumber>
  </releaseNumber>
  <source>${EMFBranch}</source>
  <user>API</user>
  <version>${EMFVERSION}</version>
</projectBundleRequestDTO>
EOF
)

  echo_output 2 "Input XML: $XML"
  echo_output 1 "Calling API to create project bundle: \
    ${EMF_API_URL}/projectbundle/generate"
  Output=$(curl $CURL_PARAM \
    -X POST \
    --header 'Content-Type: application/xml' \
    --header 'Accept: application/xml' \
    --header "Authorization: Basic $AUTH" \
    -d "${XML}" "${EMF_API_URL}/projectbundle/generate" | sed -e 's/</\n</g')
  echo_output 2 "Returned: $Output"
}
# Main Script #{{{1
init_variables
source_ini_file

# Needs to be in Main!
# Process commandline parameters
while getopts "dp?v:VhU:P:B:G:D:E:" ARGS
    do
        case ${ARGS} in
        U) url=${OPTARG} ;;
        P) ProjectID=${OPTARG} ;;
        B) DQBranch=${OPTARG} ;;
        G) GITRemote=${OPTARG} ;;
        D) GITProject=${OPTARG} ;;
        E) EMF_API_URL=${OPTARG} ;;
        v) VERBOSE=${OPTARG:-1};;
        d) VERIFY_DQ_BRANCH=n;;
        p) ProjectBundle=y;;
        V) getVersion; exit 0 ;;
        h) display_help; exit 0 ;;
        ?) display_help; exit 0 ;;
        *) display_help; exit 1 ;;
        esac
done

shift `expr ${OPTIND} - 1`

check_requirements
is_git_dir
determine_current_git_branch
debug_output

if [ -z  "${ProjectID:-}" -o \
   -z "${DQBranch:-}" -o \
   -z "${GITRemote:-}" -o \
   -z "${GITProject:-}" ]; then
  echo "Missing Parameters!"
  display_help;
  exit 1;
fi

test_dq_branch
if [ "$ProjectBundle" = "y" ]; then
  create_project_bundle
fi
download_and_process

# vim: set et tw=80 sw=0 sts=-1 ts=2 fo+=r :
