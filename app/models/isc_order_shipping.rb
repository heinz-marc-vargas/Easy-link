class IscOrderShipping < ActiveRecord::Base
  set_table_name "isc_order_shipping"
  set_primary_key "id"
  belongs_to :isc_order, :foreign_key => "orderid"
  belongs_to :isc_order_addresses, :foreign_key => "order_address_id"
  
  def self.getShippingMethod(orderid = nil)
    mtd = ""
    
    if (orderid != nil)
      mtd = IscOrderShipping.find(:all, :select => 'method', :conditions => {:order_id => orderid})[0] # Assuming 1 shipping method / order
    end
    
    return mtd
  end
  
end
