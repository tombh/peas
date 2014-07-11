module Peas
  # The default error. It's never actually raised, but can be used to catch all
  # peas-specific errors that are thrown as they all subclass from this.
  class PeasError < StandardError; end

  # Raised when something goes wrong in a worker process
  class ModelWorkerError < PeasError; end

  # Raised when there's an error shelling to the command line
  class ShellError < PeasError; end
end
