Puppet::Face.define(:node, '0.0.1') do
  action :status do
    summary "Fetch the current status for a set of nodes in PuppetDB"
    arguments "<node> [<node> ...]"
    description <<-DESC
      This action will retrieve the current status of a set of nodes from
      PuppetDB. The information provided includes whether the node is active,
      and the timestamps of its last catalog and facts. The PuppetDB server is
      found by looking in $confdir/puppetdb.conf.
    DESC

    when_invoked do |*args|
      require 'puppet/network/http_pool'
      require 'puppet/util/puppetdb'

      opts = args.pop
      raise ArgumentError, "Please provide at least one node" if args.empty?

      server = Puppet::Util::Puppetdb.server
      port = Puppet::Util::Puppetdb.port

      http = Puppet::Network::HttpPool.http_instance(server, port)

      args.map do |node|
        begin
          response = http.get("/v3/nodes/#{CGI.escape(node)}", headers)
          if response.is_a? Net::HTTPSuccess
            result = PSON.parse(response.body)
          elsif response.is_a? Net::HTTPNotFound
            result = {'name' => node}
          else
            raise "[#{response.code} #{response.message}] #{response.body.gsub(/[\r\n]/, '')}"
          end
        rescue => e
          Puppet.err "Could not retrieve status for #{node}: #{e}"
        end
        result
      end.compact
    end

    when_rendering(:console) do |value|
      value.map do |status|
        lines = [status['name']]

        # If all we have is the name, then we made this hash because of a 404
        if status.keys == ['name']
          lines << "No information known"
          next lines.join("\n")
        end

        if status['deactivated']
          lines << "Deactivated at #{status['deactivated']}"
        else
          lines << "Currently active"
        end

        if status['catalog_timestamp']
          lines << "Last catalog: #{status['catalog_timestamp']}"
        else
          lines << "No catalog received"
        end

        if status['facts_timestamp']
          lines << "Last facts: #{status['facts_timestamp']}"
        else
          lines << "No facts received"
        end

        lines.join("\n")
      end.join("\n\n")
    end
  end

  def headers
    {
      "Accept" => "application/json",
      "Content-Type" => "application/x-www-form-urlencoded; charset=UTF-8",
    }
  end
end
