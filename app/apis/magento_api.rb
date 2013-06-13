# Copyright Camptocamp SA 2012
# License: AGPL (GNU Affero General Public License)[http://www.gnu.org/licenses/agpl-3.0.txt]
# Author Guewen Baconnier

require "xmlrpc/client"
require 'pp'
XMLRPC::Config::ENABLE_NIL_PARSER = true

class MagentoAPI
  
  attr_accessor :url, :api_user, :api_key
  
  def initialize(base_url, api_user, api_key, options={})
    @url = base_url.to_s + '/api/xmlrpc/'
    @api_user = api_user
    @api_key = api_key
    @debug = options[:debug] || false
    @client = init_client
  end
  
  def call(method, *arguments)
    @client.call('call', session_id, method, arguments)
  end
  
  private
  
  def init_client
    client = XMLRPC::Client.new2(@url)
    http_debug(@debug)
    client.set_debug
    client
  end
  
  def http_debug(active)
    output = active ? $stderr : false
      
    XMLRPC::Client.class_eval do
      define_method :set_debug do
        @http.set_debug_output(output)
      end
    end
  end
  
  def session_id
    @client.call('login', @api_user, @api_key)
  end
  
end