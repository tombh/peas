#Switchboard

Switchboard is Peas' messaging system. It handles things like aggregating logs, streaming activity
to the CLI client and managing worker tasks for distributed pods.

I thought long and hard before creating something from scratch because there are a lot of existing
tools out there that do the sort of jobs Switchboard does. For instance there's NATS for pubsub,
Sidekiq for workers, DCell for distributed comms, 0MQ for messaging queues, etc. But there's nothing
that does all these things together. I'm totally prepared to find the limits of putting all our
eggs in one basket, but until then I'm hoping the simplicity of having one central tool for all
Peas' messaging needs will fit its humble aspirations.

One approach I sketched out for messaging instead of Switchboard involved many separate components;
Redis, Sidekiq (which uses Celluloid), NATS (which uses Eventmachine) and a hand cranked socket
server. It just seemed there was too much going on. They are indeed all proven tools, but I want to
keep Peas as minimal and simple as possible.

Switchboard heavily depends on Celluloid, a concurrency framework. I like to think there's something
significantly symbolic about relying on a *single* concurrency paradigm for a PaaS. A PaaS is, after
all, fundamentally concerned with scalable concurrency by definition. So having a consistent and
well defined means of concurrency in Peas' foundations will naturally spread to all its facets.

If Switchboard goes well it might be worth spinning it out into its own gem.
