require "base64"

class MageShippingAddress < ActiveRecord::Base
  set_table_name "sales_flat_order_address"
  set_primary_key "entity_id"
    
  conn = {
    :adapter  => "mysql2",
    :host     => CONFIG[:mage_host],
    :username => CONFIG[:mage_username],
    :password => Base64.decode64(CONFIG[:mage_password]),
    :database => CONFIG[:mage_dbname]
   }

  establish_connection(conn)
  reset_column_information
   
end