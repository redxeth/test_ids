require 'yaml'
module TestIds
  # The store is responsible for adding and retrieving test ID information from the
  # database.
  #
  # The database is a YAML file, which has been chosen so that it is human readable
  # and can be manually updated by hand if required.
  #
  # An instance of this class is instantiated as TestIds.store
  class Store
    attr_reader :raw, :threads

    def initialize
      @threads = {}
      threads[:load] = Thread.new { load }
    end

    # See if an existing record the for the given test name exists.
    # It so it returns a populated Test object, otherwise nil
    def find(test_name)
      threads[:load].join
      nil
    end

    # Save the given test object to the store
    def record(test)
    end

    # Loads the existing store from local storage or a remote repo
    def load
      if config.repo
        @raw = YAML.load(git.read('store') || "--- {}\n")
        # Commit an initial empty store if this is the first time it has been accessed
        unless previous_commit
          git.write('store', to_yaml)
          @raw = YAML.load(git.read('store'))
        end
      else
        @raw = YAML.load("--- {}\n")
      end
    end

    def previous_commit
      raw['previous_commit']
    end

    def to_yaml
      { 'previous_commit' => git.current_commit,
        'tests'           => tests
      }.to_yaml
    end

    def tests
      []
    end

    def git
      TestIds.git
    end

    def config
      TestIds.config
    end
  end
end
