Chef::Log.info 'Reading server connection info from data bag'

begin
  server = data_bag_item('some-service', 'server')['address']
rescue Net::HTTPServerException
  raise 'Connection info could not be loaded from data bag item'
end

file '/etc/some-service.cfg' do
  content "server = #{server}"
end
