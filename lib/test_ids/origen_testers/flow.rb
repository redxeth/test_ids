require 'origen_testers/flow'
module OrigenTesters
  module Flow
    # Override the flow.test method to inject our generated bin and
    # test numbers
    alias_method :_orig_test, :test
    def test(instance, options = {})
      unless TestIds.config.empty?
        TestIds.allocator.allocate(instance, options)
      end
      _orig_test(instance, options)
    end
  end
end
