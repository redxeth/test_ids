require 'origen'
module Origen
  class <<self
    # Override the Origen.reset_interface method to clear out the TestIds
    # configuration, so that it doesn't carry over from one flow to the next
    alias_method :_orig_reset_interface, :reset_interface
    def reset_interface(options = {})
      TestIds.send(:clear_configuration_id)
      _orig_reset_interface(options)
    end
  end
end
