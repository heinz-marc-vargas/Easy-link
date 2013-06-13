class Audit < ActiveRecord::Base
  belongs_to :user
    
  class << self
    def lists(page = 1)
      includes(:user).page(page).order("created_at DESC")
    end
    
    def delta(audit_change_log, older_audit_change_log)
      {}.tap do |d|
        # first for keys present only in this audit
        (audit_change_log.keys - older_audit_change_log.keys).each do |k|
          d[k] = [nil, audit_change_log[k]]
        end
    
        # .. then for keys present only in other audit
        (older_audit_change_log.keys - audit_change_log.keys).each do |k|
          d[k] = [older_audit_change_log[k], nil]
        end
    
        # .. finally for keys present in both, but with different values
        audit_change_log.keys.each do |k|
          if audit_change_log[k] != older_audit_change_log[k]
            d[k] = [older_audit_change_log[k], audit_change_log[k]]
          end
        end  
      end
    end
    
    def change_log_str_to_hash(audit)
      aarr = audit.change_log.split("\n").collect {|x| ( x.gsub(/  /, ""))}
      aarr_m = aarr[1..(aarr.count - 1)]
      ah = {}

      aarr_m.each do |am|
        arr = am.split(" ")
        ah[(arr[0][0] != ":")? (":" + arr[0].gsub(/:/, "")) : arr[0][0..(arr[0].length - 2)]] = (arr[1] == "!!null")? nil : arr[1]
      end
      
      return [aarr_m, ah]
    end
    
  end
  
end
