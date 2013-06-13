class IscCountryState < ActiveRecord::Base
  @@configured = false
    
  class << self
    def reconfigure_db(site_id, force = false)
      raise "Cannot establish connection. Site ID missing." if site_id.nil?
      if !@@configured || force 
        isc_site = Site.find(site_id)
        establish_connection(isc_site.database_config.decrypted_attr)
        @@configured = true
      end
    end
    
    def configured
      @@configured
    end    
        
    def for_select
      reconfigure_db(Constant::DEFAULT_SITE_ID) if !@@configured
      
      list = []
      countries = IscCountryState.order("statecountry")
      countries.each do |c|
        list << [ c.statename, c.countryiso2]
      end
      
      list
    end

  end   
end
