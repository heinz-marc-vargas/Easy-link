class Supplier < ActiveRecord::Base
  validates :company_name, :presence => true, :uniqueness => true
  has_many :products

  simple_audit do |su_record|
    {
        :name => su_record.company_name,
        :status => su_record.status,
        :username_method => User.current
    }
  end
  
  class << self
    def reconfigure_db(site_id)
      raise "Cannot establish connection. Site ID missing." if site_id.nil?

      isc_site = Site.find(site_id)
      establish_connection(isc_site.database_config.decrypted_attr)
      self.reset_column_information
    end
        
    def lists(page = 1)
      page(page).order("created_at DESC")
    end
    
    def active_suppliers
      order("company_name asc")
    end
  end
end
