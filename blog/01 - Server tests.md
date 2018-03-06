# Testing a Multi-Node Cookbook

This blog series will show examples for complex, multi-node test-kitchen scenarios using the example of a client / server application. This post will demonstrate sharing a modified data bag item between test-kitchen test instances.

## Configuring a Client / Server Application with Chef

A common Chef pattern for configuring a client / server application is to first write a server recipe to configure the server and write the connection info to a data bag item. Then write a client recipe that configures clients to connect to the server specified in the data bag item.

_To keep this example cookbook generic, we wont actually be installing any application. Instead, our recipe code will simply log out when it would install some application on the client or server._

## Write the tests first

Before we write any code, we're going to attempt to skeleton out our tests to define the goal of the code we will then write in our cookbook (this could be referred to as [_ mild test-driven development_](https://en.wikipedia.org/wiki/Test-driven_development)).

Our cookbook needs to cover two test cases:

1. `server`: The server connection info is written to a data bag item
1. `client`: The client application is configured to connect to the server using the connection info in a data bag item

We'll be using [kitchen-inspec](https://github.com/chef/kitchen-inspec) to verify our test instances as it is preferred in the community over Serverspec. Also, we'll be using the `chef-zero` provisioner to configure our test instances because it has support for serving up Chef objects like a real Chef server.

### Server tests

When chef-zero is used as the provisioner on test-kitchen instances, the chef objects like environments, roles, and data bags are stored as json files at `/tmp/kitchen/` on the test instances. So to verify the server has written to the data bag item, we can simply inspect a file that represents the data bag item on the test instance:

```ruby
# test/integration/server/default_spec.rb

describe json('/tmp/kitchen/data_bags/client_server_app/server.json') do
  its('address') { should match /\d+\.\d+\.\d+\.\d+/ }
end
```

This tests verifies that the server wrote _an_ ip address to the `"address"` key of the `server` item in the `client_server_app` data bag. Another way to write this is to verify the _correct_ ip was written to the item:

```ruby
# test/integration/server/default_spec.rb

server_ip = json('/tmp/kitchen/nodes/server-ubuntu-1604.json')['automatic']['ipaddress']

describe json('/tmp/kitchen/data_bags/client_server_app/server.json') do
  its('address') { should eq server_ip }
end
```

This verifies the ip addr from `ohai` is what was written to the data bag item.

### Client tests

Let's say the client app configuration is stored at `/etc/client_server_app.cfg` and should look like `server = <SERVER_ADDRESS>`. This test would verify _an_ ip address was written there:

```ruby
# test/integration/client/default_spec.rb

describe file('/etc/client_server_app.cfg') do
  its('content') { should match(/server = \d+\.\d+\.\d+\.\d+/) }
end
```

Again, this can be improved by matching the config to the correct ip address from the node data file in `/tmp/kitchen/nodes`:

```ruby
# test/integration/client/default_spec.rb

server_ip = json('/tmp/kitchen/nodes/server-ubuntu-1604.json')['automatic']['ipaddress']

describe file('/etc/client_server_app.cfg') do
  its('content') { should match(%r(server = #{server_ip})) }
end
```

### Kitchen YML config

```yaml
driver:
  name: vagrant

provisioner:
  name: chef_zero
  log_level: info

verifier:
  name: inspec

platforms:
  - name: ubuntu-16.04

suites:
  - name: server # defined before client so that it is converged before client
    run_list:
      - recipe[client_server_app::server]
  - name: client
    run_list:
      - recipe[client_server_app::client]
```

## Write the recipes

Now we will write the Chef recipes for the `server` and the `client`.

### Server

This is a shortened version of the code required to write the server node's ipaddress to the data bag item (the complete version handles the cases where the data bag and/or the item already exists):

```ruby
# create the data bag
bag = Chef::DataBag.new
bag.name('client_server_app')
bag.create
# create the item
item = Chef::DataBagItem.new
item.data_bag('client_server_app')

# write connection info to the data bag item
item.raw_data = {
  'id' => 'server',
  'address' => node['ipaddress']
}
item.save
```

At this point we can verify the server recipe satisfies the server test case we wrote earlier:

```shell
# install gem dependencies
bundle
# run the server test case
bundle exec kitchen test server
```

You should see successful inspec test output similar to the following:

```
  JSON /tmp/kitchen/data_bags/client_server_app/server.json
     ✔  address should eq "10.0.2.15"

Test Summary: 1 successful, 0 failures, 0 skipped
```

### Client

Reading the server ip address from the data bag item and writing it to a config file on the client node is fairly simple:

```ruby
begin
  server = data_bag_item('client_server_app', 'server')['address']
rescue Net::HTTPServerException
  raise 'Connection info could not be loaded from data bag item'
end

file '/etc/client_server_app.cfg' do
  content "server = #{server}"
end
```

Now run the client test case and see if its working:

```shell
bundle exec kitchen test client
```

Uh oh!

```
================================================================================
Recipe Compile Error in /tmp/kitchen/cache/cookbooks/client_server_app/recipes/client.rb
================================================================================

RuntimeError
------------
Connection info could not be loaded from data bag item
```

What happened? It looks like there was no data bag item to load the server connection info from because there was no server test instance converged. Generally now we would add a fixture data bag item with a fake ip address into the test. But that's not always a good idea. Maybe we want to actually run some tests with the client and server connected in test-kitchen in the future.

To make that work, we could assign a static ip address to the test server instance and put the static ip address in the data bag item. But this will have drawbacks too - what if I want to run these tests in a public or private cloud? Now I've restricted my team to only doing one build of this cookbook at a time because I'm using a static ip address in the network. Or even if its built locally in a CI/CD pipeline, I've restricted myself to one build at a time because I will have to use the static ip address.

A better solution to this is to use dynamic dhcp ip addresses for the nodes and to share the data bag item from the server instance to the client instance after the server instance converges. Add this to the `.kitchen.yml` config:

```yaml
provisioner:
  # ...
  data_bags_path: test/fixtures/data_bags
  downloads:
    /tmp/kitchen/data_bags: test/fixtures
```

The `downloads` provisioner config option will download files or directories off of test instances to the specified local path after each converge.

With this config in place, converge the `server` and then the `client` test instances:

```shell
bundle exec kitchen converge
```

> If you get the same error again: you may have defined the client suite before the server suite in `.kitchen.yml`, so the client is converging before the server converge creates the data bag item. Ensure the server suite is defined first.

You should see `test/fixtures/data_bags/client_server_app/server.json` was created after the `server` converge finished, and both converges should have succeeded.

Finally verify the client:

```shell
bundle exec kitchen verify client
```

Another error!

```
>>>>>> ------Exception-------
>>>>>> Class: Kitchen::ActionFailed
>>>>>> Message: 1 actions failed.
>>>>>>     Failed to complete #verify action: [undefined method `[]' for nil:NilClass] on client-ubuntu-1604
```

Sadly that error isn't that helpful. We can make it a little better with debug logging (`-l debug`) or by looking at logs in `./.kitchen/`. Either way, the issue is at `test/integration/client/default_spec.rb:1`:

```ruby
server_ip = json('/tmp/kitchen/nodes/server-ubuntu-1604.json')['automatic']['ipaddress']
```

Since there seems to be an issue pulling values out of that json file, we should inspect it on the node:

```shell
$ bundle exec kitchen login client
...
vagrant@client-ubuntu-1604:~$ sudo cat /tmp/kitchen/nodes/server-ubuntu-1604.json
cat: /tmp/kitchen/nodes/server-ubuntu-1604.json: No such file or directory
vagrant@client-ubuntu-1604:~$ sudo ls -lh /tmp/kitchen/nodes/
total 160K
-rw------- 1 root root 157K Mar  6 05:30 client-ubuntu-1604.json
```

The `server` node data file is not on the client node!

It seems we could share the node data file just like we shared the data bag item. But no, unfortunately chef-zero outputs node files with only root access and the test-kitchen `downloads` feature runs as the `vagrant` user:

```
-rw-r--r-- 1 root root   46 Mar  6 05:54 /tmp/kitchen/data_bags/client_server_app/server.json
-rw------- 1 root root 157K Mar  6 05:54 /tmp/kitchen/nodes/server-ubuntu-1604.json
```

Because of this, test-kitchen won't be able to download the node data file out of the test instance:

```
$ bundle exec kitchen converge server -l debug
-----> Starting Kitchen (v1.20.0)
...
-----> Converging <server-ubuntu-1604>
...
       Chef Client finished, 0/0 resources updated in 01 seconds
       Downloading files from <server-ubuntu-1604>
D      Downloading /tmp/kitchen/data_bags to test/fixtures
D      Attempting to download '/tmp/kitchen/data_bags' as file
D      Attempting to download '/tmp/kitchen/data_bags' as directory
D      Downloading /tmp/kitchen/nodes to test/fixtures
D      Attempting to download '/tmp/kitchen/nodes' as file
D      Attempting to download '/tmp/kitchen/nodes' as directory
$$$$$$ SCP download failed for file or directory '/tmp/kitchen/nodes', perhaps it does not exist?
D      Download complete
```

So the next options are

1. Update chef / test-kitchen / chef-zero to not create node files with only root permissions
1. Include a fixture recipe to change the permissions of the node data files to allow them to be shared:
```ruby
# test/fixtures/cookbooks/client_server_app_fixture/recipes/node_files_perms.rb

ruby_block 'Allow vagrant user to read node data files to copy them out of test instances' do
  block do
    Dir.glob('/tmp/kitchen/nodes/*.json') do |node_file|
      File.chmod(0644, node_file)
    end
  end
end
```
1. Save node files back to the host using [kitchen-nodes gem](https://github.com/mwrock/kitchen-nodes) and write them into each test instance with the kitchen yaml config:
```yaml
provisioner:
  name: nodes
  log_level: info
  data_bags_path: test/fixtures/data_bags
  nodes_path: test/fixtures/nodes
  downloads:
    /tmp/kitchen/data_bags: test/fixtures
```

I'm going with the `kitchen-nodes` option to get familiar with more helpful Chef testing resources available from the community. With `kitchen-nodes` added to my `Gemfile` and the `.kitchen.yml` config above set, my verify is now working. I can do a complete start to finish test with:

```
bundle exec kitchen test
```

Note that `test/fixtures/nodes/` and `test/fixtures/data_bags/` should be deleted between each run of test-kitchen converges. The directories should also be added to the `.gitignore` for the repo so this test data is not committed to source control.



future exercises:
- client searches for server based on attribute set in server recipe
- server runs nginx (apt-get install nginx) - client must hit nginx on port 80 in test
