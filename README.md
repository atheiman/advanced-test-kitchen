# Advanced Test Kitchen

Examples of complex test-kitchen Chef cookbook testing scenarios. This includes multi-node or cluster testing and modifying Chef server objects from one node and using those changes on another node.

## [`data_bag_example`](./data_bag_example)

A common Chef pattern for configuring a client / server application is to first write a server recipe to configure the server and write the connection info to a data bag item, then write a client recipe that configures clients to connect to the server specified in the data bag item. This is a complete example of this pattern thoroughly tested in test-kitchen.
