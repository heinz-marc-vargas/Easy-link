class IscOrderStatus < ActiveRecord::Base
  set_table_name "isc_order_status"
  set_primary_key "statusid"
  
  class << self
    def status_hash
      status = {}
      IscOrderStatus.all.each do |s|
        status[s.statusid] = s.statusdesc
      end
      return status
    end
  end
end
