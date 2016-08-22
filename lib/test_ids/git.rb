require 'git'
require 'yaml'
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
      @repo ||= begin
        if File.exist?(local_store)
          r = ::Git.open(local_store)
          r.reset_hard
          r.pull
          r
        else
          ::Git.clone(remote_url, local_store)
        end
      end
    end

    # Writes the data to the given file and pushes to the remote repo
    def write(path, data)
      repo # Make sure we've refreshed recently
      f = File.join(local_store, path)
      File.write(f, data)
      repo.add(f)
      repo.commit("Updated #{path}")
      repo.push('origin')
    end

    # Reads the data from the given file, returns nil if not found
    def read(path)
      repo # Make sure we've refreshed recently
      f = File.join(local_store, path)
      File.read(f) if File.exist?(f)
    end

    def current_commit
      repo.gcommit('HEAD').sha
    end

    def get_lock
      until available_to_lock?
        puts "Waiting for lock, currently locked by #{lock_user} (the lock will expire in less than #{lock_minutes_remaining} #{'minute'.pluralize(lock_minutes_remaining)} if not released before that)"
        sleep 10
      end
      data = {
        'user'    => User.current.name,
        'expires' => Time.now.utc + minutes(5)
      }.to_yaml
      write('lock', data)
    end

    def release_lock
      data = {
        'user'    => nil,
        'expires' => nil
      }.to_yaml
      write('lock', data)
    end

    def with_lock
      get_lock
      yield
    ensure
      release_lock
    end

    def available_to_lock?
      repo.pull
      if lock_content && lock_user && lock_user != User.current.name
        Time.now > lock_expires
      else
        true
      end
    end

    def lock_minutes_remaining
      ((lock_expires - Time.now) / 60).ceil
    end

    def lock_expires
      lock_content['expires']
    end

    def lock_user
      lock_content['user']
    end

    def lock_content
      if d = read('lock')
        YAML.load(d)
      end
    end

    def minutes(number)
      number * 60
    end

    def remote_url
      'ssh://git@sw-stash.freescale.net/~r49409/c402t_nvm_tester_testids.git'
    end

    def local_store
      File.join(Origen.app.imports_dir, 'test_ids', 'db')
    end
  end
end
