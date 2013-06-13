class IscOrderProduct < ActiveRecord::Base
  set_primary_key :orderprodid
  belongs_to :isc_order, :foreign_key => "orderorderid"
  belongs_to :isc_product, :foreign_key => "ordprodid"
  belongs_to :order_processing, :foreign_key => "orderprodid"


  #deprecate
  def shop_product(site_id)
     sp = ShopProduct.where("isc_product_id = ? AND site_id = ?", self.ordprodid, site_id).first
  end
    
  def shop_products(site_id)
    ShopProduct.includes(:product).where("isc_product_id = ? AND site_id = ?", self.ordprodid, site_id)
  end

  def product_variation
    product_options = self.ordprodoptions.split("\"") rescue []
    product_variation = ""
    
    unless product_options.empty?
      i = 1
      j = 1
    
      until (i > (product_options.count - 1))
        product_variation = product_variation + product_options[i] + (((j % 2) == 0)? ", " : ": ")
        i += 2
        j += 1
      end
    end
    
    product_variation = product_variation[0..(product_variation.length - 3)] unless product_variation.blank?
    return product_variation
  end

end