require 'origen'
require_relative '../config/application.rb'
require 'git'
module TestIds
  # THIS FILE SHOULD ONLY BE USED TO LOAD RUNTIME DEPENDENCIES
  # If this plugin has any development dependencies (e.g. dummy DUT or other models that are only used
  # for testing), then these should be loaded from config/boot.rb

  # Example of how to explicitly require a file
  # require "test_ids/my_file"

  # Load all files in the lib/test_ids directory.
  # Note that there is no problem from requiring a file twice (Ruby will ignore
  # the second require), so if you have a file that must be required first, then
  # explicitly require it up above and then let this take care of the rest.
  Dir.glob("#{File.dirname(__FILE__)}/test_ids/**/*.rb").sort.each do |file|
    require file
  end

  class <<self

    def repo
      if File.exist?(local_store)
        Git.open(local_store)
      else
        Git.clone(remote_url, local_store)
      end
    end

    def remote_url
      "ssh://git@sw-stash.freescale.net/~r49409/c402t_nvm_tester_testids.git"
    end

    def local_store
      File.join(Origen.app.imports_dir, 'test_ids', 'db')
    end
  end
end
