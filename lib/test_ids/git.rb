require 'git'
module TestIds
  # The Git driver is responsible for committing and fetching the
  # store from the central Git repository.
  #
  # All operations are automatically pushed immediately to the central repository
  # and a lock will be taken out whenever a program generation operation is done in
  # production mode to prevent the need to merge with other users.
  #
  # An instance of this class is instantiated as TestIds.git
  class Git
    def repo
      if File.exist?(local_store)
        ::Git.open(local_store)
      else
        ::Git.clone(remote_url, local_store)
      end
    end

    # Commits the store and pushes to the remote repo
    def commit
    end

    def read(path)
    end

    def read_or_create(path, content)
    end

    def with_lock
    end

    def remote_url
      'ssh://git@sw-stash.freescale.net/~r49409/c402t_nvm_tester_testids.git'
    end

    def local_store
      File.join(Origen.app.imports_dir, 'test_ids', 'db')
    end
  end
end
