server_ip = json('/tmp/kitchen/nodes/server-ubuntu-1604.json')['automatic']['ipaddress']

describe file('/etc/client_server_app.cfg') do
  its('content') { should match(%r(server = #{server_ip})) }
end
