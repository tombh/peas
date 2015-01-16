#!/bin/sh
# This servers the following purposes:
# 1. When first git pushing to a new domain, the user is prompted to assure the authenticity of the domain. The
#    prompt is disbaled with StrictHostKeyChecking=no
# 2. Integration tests use a known SSH key bundled with the repo to ensure they are reproducible in other
#    environments.
exec /usr/bin/ssh -o StrictHostKeyChecking=no -i /tmp/peas/.ssh/id_rsa "$@"
