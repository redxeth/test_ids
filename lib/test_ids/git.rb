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
      # Create a file name suffix based on config.id for multiple store_xxx.json and lock_xxx.json
      if options[:id].nil?
        @cfg = ''
      else
        if options[:id] == :not_specified
          @cfg = ''
        else
          @cfg = '_' + options[:id].to_s.downcase
        end
      end
      
      unless File.exist?("#{options[:local]}/.git")
        FileUtils.rm_rf(options[:local]) if File.exist?(options[:local])
        FileUtils.mkdir_p(options[:local])
        Dir.chdir options[:local] do
          `git clone #{options[:remote]} .`
          if !File.exist?("store#{cfg}.json") || !File.exist?("lock#{cfg}.json")
            # Should really try to use the Git driver for this
            exec "touch store#{cfg}.json lock#{cfg}.json"
            exec "git add store#{cfg}.json lock#{cfg}.json"
            exec 'git commit -m "Initial commit"'
            exec 'git push'
          end
        end
      end
      @local = options[:local]
      @repo = ::Git.open(options[:local])
      @repo.reset_hard
      @repo.pull unless options[:no_pull]
    end

    def cfg
      @cfg
    end
    
    def exec(cmd)
      r = system(cmd)
      unless r
        fail "Something went wrong running command: #{cmd}"
      end
    end

    def publish
      write("store#{cfg}.json")
      release_lock
      repo.commit('Publishing latest store')
      repo.push('origin')
    end

    # Writes the data to the given file and pushes to the remote repo
    def write(path, data = nil)
      f = File.join(local, path)
      File.write(f, data) if data
      repo.add(f)
    end

    def get_lock
      until available_to_lock?
        puts "Waiting for lock, currently locked by #{lock_user} (the lock will expire in less than #{lock_minutes_remaining} #{'minute'.pluralize(lock_minutes_remaining)} if not released before that)"
        sleep 5
      end
      data = {
        'user'    => User.current.name,
        'expires' => (Time.now + minutes(5)).to_f
      }
      write("lock#{cfg}.json", JSON.pretty_generate(data))
      repo.commit('Obtaining lock')
      repo.push('origin')
    end

    def release_lock
      data = {
        'user'    => nil,
        'expires' => nil
      }
      write("lock#{cfg}.json", JSON.pretty_generate(data))
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
        Time.now.to_f > lock_expires
      else
        true
      end
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
      f = File.join(local, "lock#{cfg}.json")
      JSON.load(File.read(f)) if File.exist?(f)
    end

    def minutes(number)
      number * 60
    end
    
  end
end
