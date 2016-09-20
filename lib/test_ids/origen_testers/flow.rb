require 'origen_testers/flow'
module OrigenTesters
  module Flow
    # Override the flow.test method to inject our generated bin and
    # test numbers
    alias_method :_orig_test, :test
    def test(instance, options = {})
      if TestIds.configured?
        TestIds.current_configuration.allocator.allocate(instance, options)
      end
      _orig_test(instance, options)
    end
  end
end
