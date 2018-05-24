module TestIdsDev
  class Interface
    include OrigenTesters::ProgramGenerators

    def initialize(options = {})
      case dut.test_ids
      when 1
        TestIds.configure do |config|
          # Example of testing remote repo
          # config.repo = 'ssh://git@sw-stash.freescale.net/~r49409/test_ids_repo.git'
          config.bins.include << 3
          config.bins.include << (10..20)
          config.bins.exclude << 15
          config.softbins = :bbbxx
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
