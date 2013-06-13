class IscCustomerCredits < ActiveRecord::Base
  set_primary_key "custcreditid"
  belongs_to :isc_customer, :foreign_key => "customerid"
  
end
