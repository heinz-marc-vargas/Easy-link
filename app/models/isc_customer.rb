class IscCustomer < ActiveRecord::Base
  set_primary_key "customerid"
  
  has_many :isc_orders, :foreign_key => "ordcustid"

  def customer_name
    "#{self.custconfirstname} #{self.custconlastname}".camelize rescue "N/A"
  end
end
