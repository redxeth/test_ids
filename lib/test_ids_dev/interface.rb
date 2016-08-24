module TestIdsDev
  class Interface
    include OrigenTesters::ProgramGenerators

    def initialize(options = {})
      case dut.test_ids
      when 1
        TestIds.configure do |config|
          config.bins.include << 3
          config.bins.include << (10..20)
          config.bins.exclude << 15
          config.softbins = :bbbss
          config.numbers do |options|
            options[:softbin] * 100
          end
        end
      end
    end

    def func(name, options = {})
      flow.test(name, options)
    end
  end
end
