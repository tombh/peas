#!/bin/sh
# When first git pushing to a new domain, the user is prompted to assure the authenticity of the domain. This
# wrapper is just an easy way to avois that prompt.
exec /usr/bin/ssh -o StrictHostKeyChecking=no "$@"