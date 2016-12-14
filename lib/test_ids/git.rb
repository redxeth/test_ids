require 'json'
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
    attr_reader :repo, :local

    def initialize(options)
      unless File.exist?("#{options[:local]}/.git")
        FileUtils.rm_rf(options[:local]) if File.exist?(options[:local])
        FileUtils.mkdir_p(options[:local])
        Dir.chdir options[:local] do
          `git clone #{options[:remote]} .`
          unless File.exist?('lock.json')
            # Should really try to use the Git driver for this
            exec 'touch lock.json'
            exec 'git add lock.json'
            exec 'git commit -m "Initial commit"'
            exec 'git push'
          end
        end
      end
      @local = options[:local]
      @repo = ::Git.open(options[:local])
      # Get rid of any local edits coming in here, this is only called once at the start
      # of the program generation run.
      # No need to pull latest as that will be done when we obtain a lock.
      @repo.reset_hard
    end

    def exec(cmd)
      r = system(cmd)
      unless r
        fail "Something went wrong running command: #{cmd}"
      end
    end

    def publish
      Origen.profile 'Publishing the test IDs store' do
        release_lock
        repo.add  # Checkin everything
        repo.commit('Publishing latest store')
        repo.push('origin', 'master', force: true)
      end
    end

    # Writes the data to the given file and pushes to the remote repo
    def write(path, data = nil)
      f = File.join(local, path)
      File.write(f, data) if data
      repo.add(f)
    end

    def get_lock
      return if @lock_open
      Origen.profile 'Obtaining test IDs lock' do
        until available_to_lock?
          Origen.log "Waiting for lock, currently locked by #{lock_user} (the lock will expire in less than #{lock_minutes_remaining} #{'minute'.pluralize(lock_minutes_remaining)} if not released before that)"
          sleep 5
        end
        data = {
          'user'    => User.current.name,
          'expires' => (Time.now + minutes(5)).to_f
        }
        write('lock.json', JSON.pretty_generate(data))
        repo.commit('Obtaining lock')
        repo.push('origin')
      end
      @lock_open = true
    end

    def release_lock
      data = {
        'user'    => nil,
        'expires' => nil
      }
      write('lock.json', JSON.pretty_generate(data))
    end

    def available_to_lock?
      result = false
      Origen.profile 'Checking for lock' do
        repo.fetch
        repo.reset_hard('origin/master')
        if lock_content && lock_user && lock_user != User.current.name
          result = Time.now.to_f > lock_expires
        else
          result = true
        end
      end
      result
    end

    def lock_minutes_remaining
      ((lock_expires - Time.now.to_f) / 60).ceil
    end

    def lock_expires
      lock_content['expires']
    end

    def lock_user
      lock_content['user']
    end

    def lock_content
      f = File.join(local, 'lock.json')
      JSON.load(File.read(f)) if File.exist?(f)
    end

    def minutes(number)
      number * 60
    end
  end
end
