class Site < ActiveRecord::Base
  has_and_belongs_to_many :products
  has_one :database_config
  has_many :banks

  validates :sitename, :presence => true, :uniqueness => true
  validates :sitecode, :presence => true, :uniqueness => true
  validates :site_url, :presence => true, :uniqueness => true
  validates_format_of :site_url, :with => URI::regexp(%w(http https))
  validates :hostname, :presence => true
  
  self.per_page = Constant::PERPAGE
  
  simple_audit do |s_record|
    {
        :name => s_record.sitename,
        :sitecode => s_record.sitecode,
        :site_url => s_record.site_url,
        :hostname => s_record.hostname,
        :username_method => User.current
    }
  end

  scope :enabled, lambda{ where("enabled=1") }
    
  class << self
    def lists(page=1)
      page(page).order("created_at DESC")
    end

    def get_site_id(order_id)
      return nil if order_id.nil?
      site_id = nil
 
      if order_id.to_s.length <= 8     
        first_digit = order_id.to_s.first

        case first_digit
        when "2"
          #site = 9   # BK Live
          site = Site.find_by_sitecode("BK")
        when "3"
          #site_id = 10  # PK
          site = Site.find_by_sitecode("PK")
        when "4"
          #site_id = 11  # GP
          site = Site.find_by_sitecode("GP")
        when "6"
          #site_id = 12  # HB
          site = Site.find_by_sitecode("HB")
        when "7"
          #site_id = 15  # 777
          site = Site.find_by_sitecode("777")
        when "8"
          site = Site.find_by_sitecode("KX")
        when "9"
          site = Site.find_by_sitecode("WSH")
        end
      else
        site = Site.find_by_sitecode("PKY")
      end

      return site.id unless site.nil?
      nil
    end    
  end
  
  def self.current_site
    @current_site
  end
  
  def self.current_site=(site)
    @current_site = site
    logger.info("Site: " + @current_site.inspect)
  end
  
  def self.check_sites_are_alive(site_url = nil)
    Rails.logger.info(site_url)
    
    begin
      r = Net::HTTP.get_response( URI.parse(site_url) )
      Rails.logger.info(r.inspect)
      if r.is_a? Net::HTTPSuccess
          stuff = "<span style='color:green; font-size:13px; font-weight:bold;'>Loads</span>" #r.body.force_encoding("UTF-8")
      else
        if (r.code == "503")
          stuff = "<span style='color:orange; font-size:13px; font-weight:bold;'>Under Maintenance</span>"
        elsif (r.code == "302")
          stuff = "<span style='color:#0093CD; font-size:13px; font-weight:bold;'>Found. Magento OK.</span>"
        else
          stuff = "<span style='color:red; font-size:13px; font-weight:bold;'>NOT Loading (" + r.code + ")</span>"
        end
        #nil
      end
    rescue
      stuff = "<span style='color:red; font-size:13px; font-weight:bold;'>NOT Loading</span>"
    end
    Rails.logger.info(stuff.inspect)
    
    return stuff
  end

  def db_name
    "#{self.database_config.database}"
  end  
end
