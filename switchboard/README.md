#Switchboard

Switchboard is Peas' messaging system. It handles things like aggregating logs, streaming activity
to the CLI client and managing worker tasks for distributed pods.

I thought long and hard before creating something from scratch because there are a lot of existing
tools out there that do the sort of jobs Switchboard does. For instance there's
[NATS](https://github.com/derekcollison/nats) for pubsub,
[Sidekiq](http://sidekiq.org/) for workers,
[DCell](https://github.com/celluloid/dcell) for distributed comms,
[0MQ](http://zeromq.org/) for messaging queues, etc. But there's nothing
that does all these things together. I'm totally prepared to find the limits of putting all the
eggs in one basket, but until then I'm hoping the simplicity of having one central tool for all
Peas' messaging needs will fit its humble aspirations.

One approach I seriously considered for messaging involved many separate components;
Redis, Sidekiq, NATS and a hand cranked socket
server. So that involved 3 distinct open socket ports and 2 concurrency patterns;
[Celluloid](http://celluloid.io/) for Sidekiq
and [Eventmachine](http://rubyeventmachine.com/) for NATS.
It just seemed there was too much going on. They are indeed all proven tools, but I want to
keep Peas as minimal and simple as possible.

So Switchboard depends on just one concurrency framework, namely Celluloid. I like to think there's
something significantly symbolic about relying on a *single* concurrency paradigm for a PaaS. A PaaS
is, after all, fundamentally concerned with scalable concurrency by definition. So having a
consistent and well defined means of concurrency in Peas' foundations will naturally spread to all
its facets.

##Server
The server simply receives connections, looks at the first line of data and passes the socket
to the relevant handler. Take the log streamer for instance, the first line might contain;
`stream_logs.5390f5665a454e77990b0000`. The first part `app_logs` is the name
of the command. And the next part is the DB id of the app for which the requester would like logs
for.

##Clients
Clients are agnostic. The only requirement is that they follow the protocol of placing the command
info in the first line of transmitted data. Clients don't necessarily need to use Celluloid but for
convenience you can have the clients daemon (`switchboard/bin/clients`) supervise your code with
`Celluloid::Supervisor` that automatically restarts your process if it crashes. Clients do things
like collect logs from containers and monitor pea and pod health.

###Rubygem?
If Switchboard goes well it might be worth spinning it out into its own gem.
