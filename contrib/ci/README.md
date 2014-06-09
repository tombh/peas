#Running Integration Tests on Travis

Travis CI doesn't support Docker. For most tests it suffices to record the HTTP activity that occurs through the Docker
Remote API and play it back during tests, thus negating the need for an actual live running Docker daemon. BTW we use
the very clever [VCR](https://github.com/vcr/vcr) gem to record and playback HTTP activity.

But when it comes to actually running integration tests with a real running Peas setup we have to rely on running them
on a separate remote VPS. So what the scripts in this folder do is allow us to trigger and watch the outcome of those
tests during a Travis build! `ci-server.sh` is permanently running on a remote Digital Ocean VPS and listening for a
trigger signal from `ci-client.sh`, that gets run during a Travis build. `ci-server.sh` then streams the output and
`ci-client.sh` parses it and exits with `0` if it looked like the tests where succesful and `1` if there were failures.
This way Travis, and therefore Github, know about the outcome of integration tests.

Under the hood `ci-server.sh` and `ci-client.sh` communicate via scockets using the command line utility `netcat`.
