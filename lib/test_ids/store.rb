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
    attr_reader :raw

    def initialize
      @raw = YAML.load(git.read('store') || "--- {}\n")
      # Commit an initial empty store if this is the first time it has been accessed
      unless previous_commit
        git.write('store', to_yaml)
        @raw = YAML.load(git.read('store'))
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
  end
end
