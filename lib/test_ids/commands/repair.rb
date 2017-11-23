require 'optparse'

options = {}

# App options are options that the application can supply to extend this command
app_options = @application_options || []
opt_parser = OptionParser.new do |opts|
  opts.banner = <<-EOT
Performs maintenance on the given TestId database.

Usage: origen test_ids:repair ID [options]

  EOT
  # opts.on('--bins', 'Clear the bin database') {  options[:bins] = true }
  # opts.on('--softbins', 'Clear the softbin database') {  options[:softbins] = true }
  # opts.on('--numbers', 'Clear the test number database') {  options[:numbers] = true }
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
stat = 0
begin
  # Get the commit before the lock to give the user later
  rollback_id = git.repo.object('HEAD^').sha[0, 11]
  if ARGV.empty?
    puts 'You must supply the ID of the configuration database that you wish to repair'
    exit 1
  end
  ARGV.each do |id|
    a = TestIds.load_allocator(id)
    if a
      a.repair(options)
      a.save
    else
      Origen.log.error "A configuration database named #{id} was not found!"
      stat = 1
    end
  end
ensure
  git.publish
end
if rollback_id
  puts
  puts 'TestIDs database repaired as requested, you can rollback this change by running:'
  puts
  puts "   origen test_ids:rollback #{rollback_id}"
  puts
end
exit stat
