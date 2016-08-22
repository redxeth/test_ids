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
      @raw = git.read_or_create('store')
    end

    def previous_commit
      raw[:previous_commit]
    end

    def to_yaml
      { 'previous commit' => previous_commit,
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
