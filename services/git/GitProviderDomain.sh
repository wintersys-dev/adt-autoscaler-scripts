#!/bin/sh
#: Name:        GetRepositoryDomain.sh
#: Purpose:     Resolves the primary domain name for a supported Git repository hosting provider.
#: Author:      Peter Winter
#: Date:        17/11/2026
#: Version:     1.0
#:
#: Usage:       GetRepositoryDomain.sh "<repository_provider>"
#:              GetRepositoryDomain.sh [-h|--help]
#:
#: Parameters:
#:   $1         [Required] Hosting vendor identifier (e.g. github, bitbucket, gitlab)
#:
#: Environment:
#:   BUILD_HOME Resolved automatically from /home/buildhome.dat
#:
#: Dependencies:
#:   - /home/buildhome.dat
#:   - LogStatusMessages.sh
#:   - External binaries: cat, echo, grep, cut
#:
#: Exit Codes:
#:   0          Repository provider domain resolved and emitted on stdout
#:   1          Missing required argument, missing config file, or unsupported repository provider
###################################################################################
# License Agreement:
# This file is part of The Wintersys Agile Deployment Toolkit.
# The Agile Deployment Toolkit is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# The Agile Deployment Toolkit is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with The Agile Deployment Toolkit.  If not, see <http://gnu.org>.
####################################################################################

# Exit immediately if any command exits with a non-zero status
#set -x
set -e

# Render self-extracting help documentation when -h or --help is supplied
if [ "${1}" = "-h" ] || [ "${1}" = "--help" ]
then
        /usr/bin/grep '^#:' "$0" | /usr/bin/cut -c 4-
        exit 0
fi

# Resolve the toolkit root directory from the system tracking file
if [ -r /home/buildhome.dat ]
then
        BUILD_HOME="$(/bin/cat /home/buildhome.dat)"
else
        /bin/echo "Application root configuration file missing at /home/buildhome.dat" >&2
        exit 1
fi

# Route status log entries to the centralized logging utility
status()
{
        "${BUILD_HOME}/helpers/services/LogStatusMessages.sh" "${1}" 2>/dev/null
}

# Validate required positional arguments
if [ -z "${1}" ]
then
        status "Error: Repository provider argument is required."
        status "Usage: $0 <repository_provider>"
        exit 1
fi

infrastructure_repository_provider="${1}"

# Map repository provider identifier to its canonical domain name
case "${infrastructure_repository_provider}" in
        github)
                /bin/echo "github.com"
                ;;
        bitbucket)
                /bin/echo "bitbucket.org"
                ;;
        gitlab)
                /bin/echo "gitlab.com"
                ;;
        *)
                status "Error: Unsupported repository provider (${infrastructure_repository_provider})."
                exit 1
                ;;
esac

exit 0

