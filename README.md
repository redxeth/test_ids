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
        config.numbers do |bin, softbin|
          (softbin * 10) + bin 
        end
      end
    end
~~~

## Configuration

The various ID types are generated in the following order which places some constraints on the configuration options
available to each one:

* **bin** - These are generated first, and therefore can only be configured to be generated from a range
* **softbin** - These come next, and they can be generated from a range or from either a template or a function which
  references the bin number
* **number** - The test number comes last, and they can be generated from a range or from either a template or a function which
  references the bin number and/or softbin number

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

### Assigning a Template

Softbin and test numbers can also be generated from a template. Note that if you supply a template for a given ID type
then you cannot also supply a range.

The template describes the form that the given number should have, using the following key:

* **b** - A bin number digit
* **s** - A softbin number digit
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

If your softbins or test numbers are a function which cannot be expressed using the above template rules, then you can always
fall back to a custom function.

~~~ruby
# The softbin function has access to the bin number
config.softbins do |bin|
  bin * 3
end

# And the test number function has access to the softbin too
config.numbers do |bin, softbin|
  (softbin * 10) + bin 
end
~~~

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

## Storage

The main benefit of this plugin is to get consistent number assignments accross different invocations of the program
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

### Multiple Configurations

It may be the case that you want a different configuration for wafer test vs. final test for example. Multiple
independent configurations can be created by supplying an identifier, like this:

~~~ruby
def initialize(options = {})
  TestIds.repo =  "ssh://git@github.com:myaccount/my_test_ids.git"
  
  if options[:environment] == :probe
    TestIds.configure :wafer_test do |config|
      config.bins.include << (100..500)
      config.softbins = :bbb000
      config.numbers do |bin, softbin|
        (softbin * 10) + bin 
      end
    end
  else
    TestIds.configure :final_test do |config|
      config.bins.include << (1000..2000)
      config.softbins = :bbb000
      config.numbers do |bin, softbin|
        (softbin * 10) + bin 
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

## Notes on Duplicates

The time is recorded everytime a reference is made to an ID number when generating a test program, this means
that we can identify the IDs which have not been used for the longest time - for example because they were
assigned to a test which has since been removed from the flow.

If the allocated range is exhausted then duplicates will start to be assigned starting from the oldest
referenced ID first. This should ensure that true duplicates never happen as long as your assign an
adequate range for the size of your test flow.

## What is Not Supported

Currently if you change the configuration then all bets are off and the behavior is currently undefined.
In future this plugin may support a clean up operation to assist with such changes where any IDs which are no longer
valid under the new configuration get re-generated.

