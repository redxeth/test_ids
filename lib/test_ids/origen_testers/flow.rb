require 'origen_testers/flow'
module OrigenTesters
  module Flow
    # Override the flow.test method to inject our generated bin and
    # test numbers
    alias_method :_orig_test, :test
    def test(instance, options = {})
      TestIds.allocator.allocate(instance, options, _test_ids_config)
      _orig_test(instance, options)
    end

    def _test_ids_config
      if Origen.interface.respond_to?(:test_ids_config)
        Origen.interface.test_ids_config
      else
        Origen.app.config.test_ids
      end
    end
  end
end
