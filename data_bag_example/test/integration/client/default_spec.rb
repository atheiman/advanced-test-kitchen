server_node = JSON.parse(
  File.read(
    Dir.glob(
      File.join(
        File.dirname(__FILE__), '../../fixtures/nodes/server*.json'
      )
    ).first
  )
)

server_ip = server_node['automatic']['ipaddress']

describe file('/etc/some-service.cfg') do
  its('content') { should match(%r(server = #{server_ip})) }
end
