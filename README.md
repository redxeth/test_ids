[![Build Status](https://travis-ci.org/Origen-SDK/test_ids.svg?branch=master)](https://travis-ci.org/Origen-SDK/test_ids)
[![Coverage Status](https://coveralls.io/repos/github/Origen-SDK/test_ids/badge.svg?branch=master)](https://coveralls.io/github/Origen-SDK/test_ids?branch=master)

# test_ids

An Origen plugin to automatically assign and maintain test program bin and test numbers.

This plugin integrates with OrigenTesters and allows you to assign a range of numbers, or a function, to generate bin,
softbin, and test numbers whenever you generate a test program with Origen.
Unlike similar algorithms that may be implemented within an application, test_ids will maintain a record of the numbers assigned
to each test so that they will stick even if the test flow order changes.

## Integration

Simply add the gem to your application via the Gemfile. If your application is a plugin, then add it to your .gemspec and
require it somewhere (at the top of your test program interface would be a good place):

~~~ruby
require 'test_ids'
~~~

All that is required is then to configure the plugin in your interface's initialize method:

~~~ruby
# my_interface.rb
module MyApp
  class Interface
    include OrigenTesters::ProgramGenerators
    
    def initialize(options = {})
      TestIds.repo =  "ssh://git@github.com:myaccount/my_test_ids.git"
      
      TestIds.configure do |config|
        config.bins.include << (100..500)
        config.softbins = :bbb000
        config.numbers needs: [:bin, :softbin] do |options|
          (options[:softbin] * 10) + options[:bin] 
        end
      end
    end
~~~


Then, anytime that you call `flow.test(my_test_instance, options)` within your application's interface, assignments for `:bin`, `:softbin` and `:number` will automatically be injected into the options before it hits OrigenTesters.
If an entry for any of the keys is already present in the options, then that will be given priority and TestIds will not attempt to assign a value for that attribute.

If you want to prevent TestIds from generating a given attribute and really pass `nil` for that attribute to OrigenTesters, then assign it to the value `:none`:

~~~ruby
flow.test my_test, bin: :none   # Assign no bin but allow TestIds to generate a softbin and test number
~~~

A method is also provided to directly assign/retrieve the numbers for a given test from TestIds, this should be supplied with the same arguments that you would normally pass to `flow.test`:

~~~ruby
TestIds.allocate(my_test, options)   # => { bin: 5, bin_size: 1, softbin: 1250, softbin_size: 1, number: 10250010, number_size: 1 }

# The above returns the same numbers that would be injected into the options when calling:
flow.test my_test, options
~~~

The convenience methods `allocate_bin`, `allocate_softbin` and `allocate_number` exist to generate only the respective number type:

~~~ruby
TestIds.allocate_number(my_test, options)   # => { number: 10250010, number_size: 1 }
~~~

If you want to prevent TestIds from tracking/assigning to a given test you can supply a no-track option:

~~~ruby
flow.test my_test, bin: 10, test_ids: :notrack
~~~


## Configuration

All ID types (bin, softbin or number), can be generated from either a range, an algorithm, or a function. There now follows a description
of how to configure each one...

### Assigning a Range

All ID types can be given an independent range of numbers to pick from like this (where TYPE is bins, softbins or numbers):

~~~ruby
config.TYPE.include << 3           # Number 3 only
config.TYPE.include << (100..200)  # Also includes numbers from 100 to 200
~~~

This can be called multiple times for the same ID type if your allocation is comprised of a non-contiguous range.

Certain numbers within the include allocation can be excluded like this:

~~~ruby
config.TYPE.exclude << 150         # This is already assigned to something else
config.TYPE.exclude << (190..195)  # A range is also acceptable
~~~

When numbers are being assigned from a range, they will be selected based on an increment of 1 by default. However,
in cases where you want multiple numbers to be reserved by each test you can change the default like this:

~~~ruby
config.TYPE.size = 5   # Reserve 5 numbers for each test by default
~~~

Then for a given range of 100 to 200 say, it would be assigned as 100, 105, 110, etc.

It is possible to override the size for an individual test by passing one or more of the options shown in
the example below:

~~~ruby
flow.test my_test, bin_size: 2, softbin_size: 10, number_size: 100
~~~


### Assigning an Algorithm

Softbin and test numbers can also be generated from an algorithm. Note that if you supply an algorithm for a given ID type
then you cannot also supply a range.

The template describes the form that the given number should have, using the following key:

* **b** - A bin number digit
* **s** - A softbin number digit
* **n** - A test number digit
* **x** - A uniqueness counter
* **0-9** - A static digit

For example, to make the softbins equal to the bin number * 100, you can simply do:

~~~ruby
config.softbins = :bbb00
~~~

For bins 1, 2, 3 this would generate softbins 100, 200, 300.

Suppose that you have many tests assigned to the same bin number and you would like the softbins to be unique. In that case
you can make some of the digits a unique counter instead:

~~~ruby
config.softbins = :bbbxx
~~~

If all of your tests were bin 3 for example, then this would assign softbins 300 to 399.

### Assigning a Function

If your numbers need to be derived from a function which cannot be expressed using the above algorithm rules, then you can always
fall back to a custom callback function, here are some examples:

~~~ruby
config.softbins needs: :bin do |options|
  options[:bin] * 3
end

config.numbers needs: [:bin, :softbin] do |options|
  (options[:softbin] * 10) + options[:bin] 
end
~~~

The callback function will have access to all options passed into `flow.test` by your test program flow, or any passed to
`TestIDs.allocate` if called directly.

Additionally, you should indicate if your function depends on one of the other number types (bin, softbin or number) via the
`:needs` option as shown.
This will ensure that TestIds generates them in the correct order required to ensure that the dependent type is always available
in the options.

Note that the natural generation order may mean that it appears to work without supplying the `:needs` information, however it
is recommended to always supply this to ensure robust operation across all corner cases.


## Manual Allocation

Any test can be manually assigned to either of these ID types and that will take precedence:

~~~ruby
func :my_functional_test, bin: 3, softbin: 100, number: 200100
~~~

The given numbers will be then be reserved and excluded from automatic assignment.

In the case where the number had already been automatically given out to a test earlier in the flow, it will be
reclaimed the next time the program generator is run.

## Multiple Instances of the Same Test

The assigned numbers are stored in a database by test name, such that any references to the same test name will always
be assigned the same numbers.

~~~ruby
func :my_functional_test
func :my_functional_test  # Would be assigned the same numbers as above
~~~

If a different set of numbers is desired on the 2nd occurence, then ideally this should be reflected by assigning a
different test name.

If that is not possible then an index option can be used to differentiate them:

~~~ruby
func :my_functional_test
func :my_functional_test, index: 1  # Will be treated like a different test and assigned a different number
~~~

Additionally, a :test_id option can be used to make test_ids treat differently named tests
the same for the purposes of assigning numbers:

~~~ruby
func :my_func_33mhz, test_id: :my_func  # Will all be treated like the same test by test_ids,
func :my_func_25mhz, test_id: :my_func  # and will therefore all be assigned the same numbers
func :my_func_16mhz, test_id: :my_func
~~~

Sometimes you may even want duplicate tests to be treated the same as far as the bin number goes, but you
would like them to have unique test numbers (for example).

That can be achieved by setting the <code>:bin</code>, <code>:softbin</code> or <code>:number</code> options
to a Symbol or String value as shown below:

~~~ruby
# These will have the same bin and softbin number, but unique test numbers
func :my_func_33mhz, test_id: :my_func, number: :my_func_33mhz
func :my_func_25mhz, test_id: :my_func, number: :my_func_25mhz
func :my_func_16mhz, test_id: :my_func, number: :my_func_16mhz

# This time, unique softbin and test numbers, but the same bin
func :my_func_33mhz, bin: :my_func
func :my_func_25mhz, bin: :my_func
func :my_func_16mhz, bin: :my_func
~~~

Finally, if the same test occurs in multiple test flows then it will be assigned the same numbers
unless it has been differentiated by one of the approaches discussed above.

However, if you generally want to treat tests within different flows as being different, then setting the
`unique_by_flow` configuration option to `true` will cause TestIds to append the flow name to whatever the
test ID had otherwise been resolved to, thereby ensuring that matching tests in different flows
will be treated as different tests:

~~~ruby
TestIds.configure :my_config do |config|
  config.unique_by_flow = true
end
~~~

## Next In Range (Beta Feature)

This feature enables user-specified number ranges to be used within callback functions and TestIds will keep track of
how many numbers in the range have been consumed so far.

This is best shown by example:

~~~ruby
TestIds.configure :wafer_test do |config|
  config.bins.include << (1..5)
  config.softbins.size = 5
  config.softbins needs: :bin do |options|
    if options[:bin] == 1
      TestIds.next_in_range((1000..2000))
    else
      TestIds.next_in_range((10000..99999), size: 5)   # Increment by 5 instead of the default of 1
    end
  end
end
~~~

The `next_in_range` method will increment through the range and return the next number. The last number given out is recorded
in the TestIds database so that it will continue from that point the next time.

Note that use of the same ranges for more than one ID type (bin, softbin or number) within the configurations has not yet been verified,
and will most likely need further enhancements to this method.

For more examples, please look at the examples in the `spec/specific_ranges.rb` file.

*Note that if the end of the provided range is reached, the plugin will display an Origen error log warning and raise an exception, thus stopping generation until the range is increased.*

~~~text
[ERROR]      2.500[0.051]    || Assigned value not in range

COMPLETE CALL STACK
-------------------
...
~~~


## Storage

The main benefit of this plugin is to get consistent number assignments across different invocations of the program
generator, and for that to work it is necessary for the database to be stored somewhere.
The database is a single file that is written in JSON format to make it human readable in case there is ever a need to
manually modify it.

A dedicated Git repository is used to store this file, this means that it will be
shared by different users of your application and they will all see a consistent view of the number
allocations.

To enable Git storage create a new empty repository somewhere. This repository should be dedicated for use by this
plugin and not used for anything else.
**It must be writable by all users of your application.**

Once you have the repository, configure test_ids to use it like this:

~~~ruby
# This must be done before configuring
TestIds.repo =  "ssh://git@github.com:myaccount/my_test_ids.git"

TestIds.configure do |config|
  #...
~~~

The repository will then be kept up to date on every program generator invocation.
A locking system will be automatically managed for you to prevent concurrent updates from multiple users.

Sometimes during development you may want to temporarily inhibit publishing to the repo,
that can be achieved like this:

~~~ruby
TestIds.repo =  "ssh://git@github.com:myaccount/my_test_ids.git"
TestIds.publish = false
~~~

A common configuration may be to only publish in production:

~~~ruby
TestIds.repo =  "ssh://git@github.com:myaccount/my_test_ids.git"
TestIds.publish = Origen.mode.production?
~~~

## Multiple Configurations

It may be the case that you want a different configuration for wafer test vs. final test for example. Multiple
independent configurations can be created by supplying an identifier, like this:

~~~ruby
def initialize(options = {})
  TestIds.repo =  "ssh://git@github.com:myaccount/my_test_ids.git"
  
  if options[:environment] == :probe
    TestIds.configure :wafer_test do |config|
      config.bins.include << (100..500)
      config.softbins = :bbb000
      config.numbers needs: [:bin, :softbin] do |options|
        (options[:softbin] * 10) + options[:bin] 
      end
    end
  else
    TestIds.configure :final_test do |config|
      config.bins.include << (1000..2000)
      config.softbins = :bbb000
      config.numbers needs: [:bin, :softbin] do |options|
        (options[:softbin] * 10) + options[:bin] 
      end
    end
  end
end
~~~

In the above example the environment option would be passed in from the top-level flow, like this:

~~~ruby
Flow.create environment: :probe do
  # ...
end
~~~

### Multiple Active Configurations

It is also possible to define multiple configurations and then switch back and forth between them at runtime.

If you test program interface logic defines multiple configurations at runtime like this:

~~~ruby
TestIds.repo =  "ssh://git@github.com:myaccount/my_test_ids.git"
  
TestIds.configure :my_config_1 do |config|
  config.bins.include << (100..500)
  config.softbins = :bbb000
  config.numbers needs: [:bin, :softbin] do |options|
    (options[:softbin] * 10) + options[:bin] 
  end
end

TestIds.configure :my_config_2 do |config|
  config.bins.include << (1000..2000)
  config.softbins = :bbb000
  config.numbers needs: [:bin, :softbin] do |options|
    (options[:softbin] * 10) + options[:bin] 
  end
end
~~~

Then, by default the active configuration will be the last one that was defined, `:my_config_2` in this case.

The valid configs can be listed:

~~~ruby
TestIds.configs # => [:my_config_1, :my_config_2]
~~~

To switch the active configuration use this API:

~~~ruby
TestIds.allocate(my_test, options)    # Allocated from :my_config_2

TestIds.config = :my_config_1

TestIds.allocate(my_test, options)    # Allocated from :my_config_1
~~~

or to temporarily switch:

~~~ruby
TestIds.allocate(my_test, options)    # Allocated from :my_config_2

TestIds.with_config :my_config_1 do

  TestIds.allocate(my_test, options)    # Allocated from :my_config_1

end

TestIds.allocate(my_test, options)    # Allocated from :my_config_2
~~~

Finally, it is even possible to enable different configurations for different ID types:

~~~ruby
TestIds.bin_config = :my_config_1
TestIds.softbin_config = :my_config_1
TestIds.number_config = :my_config_2

TestIds.allocate(my_test, options)    # Bin and Softbin allocated from :my_config_1, Number from :my_config_2
~~~

If only `TestIds.number_config` had been set, then the others would continue to be allocated from the default
active configuration.

## Notes on Duplicates

The time is recorded each time a reference is made to an ID number when generating a test program, this means
that we can identify the IDs which have not been used for the longest time - for example because they were
assigned to a test which has since been removed from the flow.

If the allocated range is exhausted then duplicates will start to be assigned starting from the oldest
referenced ID first. This should ensure that true duplicates never happen as long as you assign an
adequate range to cover the size of your test flow.

## What is Not Supported

Currently if you change the configuration then all bets are off and the behavior is currently undefined.
In future this plugin may support a clean up operation to assist with such changes where any IDs which are no longer
valid under the new configuration get re-generated.

