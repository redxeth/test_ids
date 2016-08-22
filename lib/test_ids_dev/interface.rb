module TestIdsDev
  class Interface
    include OrigenTesters::ProgramGenerators

    def func(name, options = {})
      flow.test(name, options)
    end
  end
end
