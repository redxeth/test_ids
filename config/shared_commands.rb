# The requested command is passed in here as @command
case @command

when "test_ids:rollback"
  if ARGV[0]
    TestIds::Git.rollback(ARGV[0])
  else
    puts "You must supply a commit ID to rollback to, e.g. origen test_ids:rollback 456ac3f53"
  end
  exit 0
else
  @plugin_commands << <<-EOT
 test_ids:rollback  Rollback the TestIds store to the given commit ID
  EOT

end
