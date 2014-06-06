class LogsCursor

  def initialize app
    @app = app
  end

  def existing
    # Mongoid apparently creates a new session for every thread, so as long as the thread dies, so too does the
    # underlying Moped session.
    @cursor = Mongoid::Sessions.default["#{@app.first_sha}_logs"].find.tailable.cursor
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