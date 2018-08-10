require 'origen_testers/flow'
module OrigenTesters
  module Flow
    BIN_OPTS = [:bin, :softbin, :bin_size, :softbin_size, :number, :number_size]

    # Override the flow.test method to inject our generated bin and
    # test numbers
    alias_method :_orig_test, :test
    def test(instance, options = {})
      if TestIds.configured?
        unless options[:test_ids] == :notrack
          options[:test_ids_flow_id] = try(:top_level).try(:id) || id

          TestIds.current_configuration.allocator.allocate(instance, options)

          unless TestIds.current_configuration.send_to_ate?
            BIN_OPTS.each do |opt|
              options.delete(opt)
            end
          end
        end
      end
      _orig_test(instance, options)
    end
  end
end
