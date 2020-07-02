
# The git-omni-deployment Repository [![Say Thanks!](https://img.shields.io/badge/Say%20Thanks-!-1EAEDB.svg)](https://saythanks.io/to/cb%40256bit.org)

This repository contains a tool to ease creating the deployment bundle for [Omni-Gen](https://www.ibi.com/data-platform/).

Simply clone this tool somewhere and put it into the path.


## Usage:

		USAGE: omni.sh -P <ProjectID> -B <DQBranch> -U <URL> -G <Git_Remote> -D <DQProject>
		USAGE: omni.sh [-v<nr>Vh?]

		Download the deployment bundle for Omni using
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

		Version: 0.4

## Configuration

As mentioned in the Usage section above, you need to call the script with
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

