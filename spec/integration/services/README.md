These tests are not automatically run because they require that the relevant service be installed
on the testers system. Eg; MongoDB, Postgres, Memcache, etc

Currently only MongoDB is tested in the full integration suite. If we find a suitable means of the
inner Docker containers in DinD of accessing services on the originating host then maybe it will be
better to just subsume these tests into the full integration suite.