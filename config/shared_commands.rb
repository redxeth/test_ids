# The requested command is passed in here as @command
case @command

when "test_ids:rollback"
  if ARGV[0]
    local = TestIds::Git.path_to_local
    TestIds::Git.new(local: local).rollback(ARGV[0])
  else
    puts "You must supply a commit ID to rollback to, e.g. origen test_ids:rollback 456ac3f53"
  end
  exit 0

when "test_ids:clear"
  require "test_ids/commands/#{@command.split(':').last}"
  exit 0

else
  @plugin_commands << <<-EOT
 test_ids:rollback  Rollback the TestIds store to the given commit ID
 test_ids:clear     Clear the assignment database for bins, softbins, numbers or all
  EOT

end
