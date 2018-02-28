Chef::Log.info 'Writing server connection info to data bag'

begin
  # try getting the item
  item = data_bag_item('some-service', 'server')
rescue Net::HTTPServerException
  begin
    # try getting the bag
    data_bag('some-service')
  rescue Net::HTTPServerException
    # create the bag
    bag = Chef::DataBag.new
    bag.name('some-service')
    bag.create
  end
  # create the item
  item = Chef::DataBagItem.new
  item.data_bag('some-service')
end

# write connection info to the data bag item
item.raw_data = {
  'id' => 'server',
  'address' => node['ipaddress']
}
item.save

Chef::Log.info 'Server connection info written to data bag'
