require 'optparse'

options = {}

# App options are options that the application can supply to extend this command
app_options = @application_options || []
opt_parser = OptionParser.new do |opts|
  opts.banner = <<-EOT
Clear all existing bin, softbin or test number allocations in the given TestId database.

Usage: origen test_ids:clear [ID] [options]

Examples: origen test_ids:clear --bins                      # Clear the bins in the default database
          origen test_ids:clear wafer_test --numbers        # Clear the test numbers in the wafer_test database
          origen test_ids:clear --bins --softbin --numbers  # Clear everything in the default database

  EOT
  opts.on('--bins', 'Clear the bin database') {  options[:bins] = true }
  opts.on('--softbins', 'Clear the softbin database') {  options[:softbins] = true }
  opts.on('--numbers', 'Clear the test number database') {  options[:numbers] = true }
  # opts.on('-pl', '--plugin PLUGIN_NAME', String, 'Set current plugin') { |pl_n|  options[:current_plugin] = pl_n }
  opts.on('-d', '--debugger', 'Enable the debugger') {  options[:debugger] = true }
  app_options.each do |app_option|
    opts.on(*app_option) {}
  end
  opts.separator ''
  opts.on('-h', '--help', 'Show this message') { puts opts; exit 0 }
end

opt_parser.parse! ARGV

local = TestIds::Git.path_to_local
git = TestIds::Git.new(local: local)
TestIds.repo = git.repo.remote.url
git.get_lock
rollback_id = nil
begin
  # Get the commit before the lock to give the user later
  rollback_id = git.repo.object('HEAD^').sha[0, 11]
  a = TestIds.load_allocator(ARGV.first)
  a.clear(options)
  a.save
ensure
  git.publish
end
if rollback_id
  puts
  puts 'TestIDs database cleared as requested, you can rollback this change by running:'
  puts
  puts "   origen test_ids:rollback #{rollback_id}"
  puts
end
