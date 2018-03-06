# Multi-Node Test Kitchen

Examples covered:

- Write config to a data bag item in one node's converge then, use that data in the converge of another node.
- Write a secret to an encrypted data bag item in one node's converge then, use that secret in the converge of another node.
- Write a secret to a Chef vault item in one node's converge then, use that secret in the converge of another node.
- Search for another node (using normal attributes from `kitchen-nodes` and using attributes set in the node's converge)

## Scenario

A common Chef pattern for configuring a client / server application is to first write a server recipe to configure the server and write the connection info to a data bag item, then write a client recipe that configures clients to connect to the server specified in the data bag item. This cookbook is a complete example of this pattern thoroughly tested in test-kitchen.

## Recipes

The cookbook contains a [`server` recipe](./recipes/server.rb) and a [`client` recipe](./recipes/client.rb) that satisfy the requirements outlined in the above scenario.

## Testing Info

The testing setup here makes use of a couple of advanced test-kitchen methods:

- The Chef-Zero provisioner's `downloads` config is used in the [`.kitchen.yml`](./.kitchen.yml) to download the modified data bag item out of the `/tmp/kitchen/data_bags` directory on the `server` test-kitchen instance to `test/fixtures/data_bags` on the host running test-kitchen. This `downloads` functionality is new as of test-kitchen v1.20 (January 2018).
- The [`Kitchen::Nodes` test-kitchen provisioner](https://github.com/mwrock/kitchen-nodes) is used to write the `server` test-kitchen instance node data to a json file in `test/fixtures/nodes` on the host. In the inspec test for the `client` configuration, the ipaddress of the `server` instance is read from the node data file at `test/fixtures/nodes/server*.json`. Then the inspec test verifies that `server` instance's ip is written into a config file on the `client` instance.
  - This only adds value to local (VirtualBox) setups where ssh access to all test-kitchen instances is setup by a host port forward. When test-kitchen instances are accessed by different ip addresses ([`kitchen-ec2` for example](https://github.com/test-kitchen/kitchen-ec2)), the inspec test can read the `server` instance's ip address from `.kitchen/server*.yml` rather than a node attribute data file like `test/fixtures/nodes/server*.json`.

### Run the tests

```shell
# install gem dependencies
bundle
# converge and destroy the 
```
