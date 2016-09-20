module TestIds
  class ShutdownHandler
    include Origen::PersistentCallbacks

    def on_origen_shutdown
      TestIds.send(:on_origen_shutdown)
    end
  end
  # Instantiate an instance of this class immediately when this file is loaded, this object will
  # then listen for the remainder of the Origen thread
  ShutdownHandler.new
end
