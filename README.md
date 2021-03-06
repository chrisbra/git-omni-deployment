
# The git-omni-deployment Repository [![Say Thanks!](https://img.shields.io/badge/Say%20Thanks-!-1EAEDB.svg)](https://saythanks.io/to/cb%40256bit.org)

This repository contains a tool to ease creating the project and deployment bundle for [Omni-Gen][1].

## Installation
Simply clone this tool somewhere and put it into the path.

## Usage:

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
    -v<nr>	- verbose output (<nr> is verbose level, higher the more verbose)
    -V		- return version
    -h		- this help page
    -?		- this help page

    Uses <URL> for downloading (default: https://localhost:9502 if not given).
    Uses <DQProject> for the DQ Project (usually shouldn't change).

    The resulting deployment bundle will be stored in the current directory.

		Version: 0.4

## Configuration

As mentioned in the [Usage section][2] above, you need to call the script with
*ProjectID* (the Omni Project, visible in the deployment console), the git
data quality branch (*DQBranch*), the URL for the deployment console (usually
something with port 9502, *URL*), the URL for the git repository (*GIT_Remote*)
and the name of the data quality project associated with the Omni bundle
(*DQProject*)

For ease of use, those parameters can be set in the `omni_deployment.ini` file
and it will be read automatically, if it exists in the current working
directory.


## Legal
__NO WARRANTY, EXPRESS OR IMPLIED.  USE AT-YOUR-OWN-RISK__

[1]:https://www.ibi.com/data-platform/
[2]:https://github.com/chrisbra/git-omni-deployment#usage
