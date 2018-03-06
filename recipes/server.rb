Chef::Log.info 'Writing server connection info to data bag'

begin
  # try getting the item
  item = data_bag_item('client_server_app', 'server')
rescue Net::HTTPServerException
  begin
    # try getting the bag
    data_bag('client_server_app')
  rescue Net::HTTPServerException
    # create the bag
    bag = Chef::DataBag.new
    bag.name('client_server_app')
    bag.create
  end
  # create the item
  item = Chef::DataBagItem.new
  item.data_bag('client_server_app')
end

# write connection info to the data bag item
item.raw_data = {
  'id' => 'server',
  'address' => node['ipaddress']
}
item.save

Chef::Log.info 'Server connection info written to data bag'
