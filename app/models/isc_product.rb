class IscProduct < ActiveRecord::Base
  set_primary_key "productid"
  belongs_to :isc_order_product, :foreign_key => "ordprodid"
  belongs_to :medex_product_map, :foreign_key => "product_id"
#  has_many :shop_products, :foreign_key => "product_id" 
  has_many :shop_products, :foreign_key => "isc_product_id"

  class << self
    def lists(options = {})
      site_id = nil
      page = options[:page] || 1
      isc_products = page(page).order("isc_products.productid DESC")

      if options.has_key? :per_page
        isc_products = isc_products.per_page(options[:per_page].to_i) unless options[:per_page].blank?
      end
      
      if options.has_key? :q
        isc_products = isc_products.where("isc_products.prodname like ? OR isc_products.productid = ? OR isc_products.prodcode like ?", "%#{options[:q]}%", "#{options[:q]}", "%#{options[:q]}%") unless options[:q].blank?
      end

      isc_products
    end
    
    def create_cart_product(site_id, product_code, product_name, product_id)
      IscOrder.reconfigure_db(site_id)
      prod = IscProduct.new(:prodcode => product_code, :prodname => product_name)
      if prod.save
        sql_str = "UPDATE isc_products SET productid = " + product_id.to_s + " WHERE productid = " + prod.productid.to_s
        IscProduct.connection.execute(sql_str)  # This is not logged in Audits, that's why we do a .new(...) first. 
      end
    end
    
  end
  
end
