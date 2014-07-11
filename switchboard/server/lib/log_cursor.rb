# Retrieves the aggregated logs from a capped MongoDB collection in real time. Provices tail-like
# reading of logs.
# Note that Mongoid apparently creates a new session for every thread. You can think of every
# Celluloid actor being a thread. So as long as the thread ends, so too does the underlying Moped
# session.
class LogsCursor
  include Celluloid::IO

  def initialize(app)
    @app = app
  end

  # Return the existing logs for an app
  def existing
    @cursor = @app.logs_collection.find.tailable.cursor
    # Grab a handful of the logs to get us going
    @cursor.load_docs.each do |doc|
      line = doc['line']
      if block_given?
        yield line
      else
        puts line
      end
    end
  end

  # The cursor keeps track of what has already been returned and checks to see if new log lines
  # have been added since the last request.
  def more
    if @cursor.more?
      @cursor.get_more.each do |doc|
        line = doc['line']
        if block_given?
          yield line
        else
          puts line
        end
      end
    end
  end
end
