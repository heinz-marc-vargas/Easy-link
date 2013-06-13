class IscCountry < ActiveRecord::Base
  @@configured = false
    
  class << self
    def reconfigure_db(site_id, force = false)
      raise "Cannot establish connection. Site ID missing." if site_id.nil?
      if !@@configured || force 
        if Rails.env == "production"
          puts "**************************************************** ESTABLISH CONNECTION ***********************************"
          isc_site = Site.find(site_id)
          establish_connection(isc_site.database_config.decrypted_attr)
          @@configured = true
        else
          isc_site = Site.find(site_id)
          establish_connection "#{Rails.env}_#{isc_site.sitecode}"
          reset_column_information
        end
      end
    end
    
    def configured
      @@configured
    end    
        
    def for_select
      reconfigure_db(Constant::DEFAULT_SITE_ID) if !@@configured
      
      list = []
      #currently just shipping to JAPAN
      countries = IscCountry.where("countryiso2='JP'")
      countries.each do |c|
        list << [ c.countryname, c.countryiso2]
      end
      
      list
    end

  end  
end
