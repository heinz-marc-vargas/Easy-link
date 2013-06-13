class IscOrderAddress < ActiveRecord::Base
  set_primary_key "id"
  belongs_to :isc_order, :foreign_key => "order_id"
  has_one :isc_order_shipping

  validates :order_id, :presence => true
  validates :first_name, :presence => true
  validates :last_name, :presence => true
  validates :address_1, :presence => true
  #validates :city, :presence => true
  validates :zip, :presence => true
  validates :phone, :presence => true
  
  def street
    Helpers.convert_multi_to_single_byte_alpha_num("#{self.address_1} #{self.address_2}").strip
  end
  
  def complete_address
    Helpers.convert_multi_to_single_byte_alpha_num("#{street} #{city} #{state} #{zip} #{country}")
  end
  
  simple_audit do |addr_record|
    {
        :first_name => addr_record.first_name,
        :last_name => addr_record.last_name,
        :email => addr_record.email,
        :phone => addr_record.phone,
        :address_1 => addr_record.address_1,
        :address_2 => addr_record.address_2,
        :city => addr_record.city,
        :state_id => addr_record.state_id,
        :state => addr_record.state,
        :zip => addr_record.zip,
        :country_id => addr_record.country_id,
        :country_iso2 => addr_record.country_iso2,
        :country => addr_record.country,
        :site_id => (Site.current_site.id rescue nil),
        :username_method => User.current
    }
  end
end