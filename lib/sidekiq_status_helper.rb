# Provide a class method that can update a job from any scope.
# It is merely a copy of the protected Sidekiq::Status.store_for_id() method.
module Sidekiq::Status
  class << self
    def broadcast jid, status_updates
    	Sidekiq.redis do |conn|
    	  conn.multi do
    	    conn.hmset  jid, 'update_time', Time.now.to_i, *(status_updates.to_a.flatten(1))
    	    conn.expire jid, Sidekiq::Status::DEFAULT_EXPIRY
    	    conn.publish "status_updates", jid
    	  end[0]
    	end
    end
  end
end