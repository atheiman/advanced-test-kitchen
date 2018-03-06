server_ip = json('/tmp/kitchen/nodes/server-ubuntu-1604.json')['automatic']['ipaddress']

describe json('/tmp/kitchen/data_bags/client_server_app/server.json') do
  its('address') { should eq server_ip }
end
