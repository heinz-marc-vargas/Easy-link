#encoding: utf-8
class Product < ActiveRecord::Base
  belongs_to :creator, :polymorphic => true
  has_many :shop_products
  has_and_belongs_to_many :sites
  belongs_to :supplier

  validates :name, :presence => true #, :uniqueness => true
  validates :supplier_id, :presence => true
  validates :ext_product_id, :presence => true, :uniqueness => true
  
  UNASSOCIATED_UID = 0
  
  simple_audit do |p_record|
    {
        :supplier_id => p_record.supplier_id,
        :ext_product_id => p_record.ext_product_id,
        :uid => p_record.uid,
        :name => p_record.name.to_s,
        :stock => p_record.stock,
        :restock_threshold => p_record.restock_threshold,
        :restock_notification_sent => p_record.restock_notification_sent,
        :username_method => User.current
    }
  end
  
  self.per_page = Constant::PERPAGE
  
  class << self

    #hash keys: prod_id, product_ids, qty, site_id
    def product_string(hash, supplier_id)
      puts hash.inspect
      isc_order_product_id = hash[:product_ids] 
      qty = hash[:qty]
      site_id = hash[:site_id]
      prod_id = hash[:prod_id].to_i
      
      ioprod = IscOrderProduct.find_by_orderprodid(isc_order_product_id)
      shop_prod = ShopProduct.where("isc_product_id=? AND site_id = ?", ioprod.ordprodid, site_id).first
     
      if shop_prod.supplier_id.to_i != supplier_id.to_i
        prod = Product.where("uid=? and supplier_id = ? and uid != 0", shop_prod.product.uid, supplier_id).first rescue nil
      else
        prod = Product.find(prod_id.to_i) rescue nil
        unless prod.nil?
          if prod.uid > 0
            prod = Product.where("uid=? and supplier_id = ?", prod.uid, supplier_id).first rescue nil
          end
        end
      end
      
      return '' if prod.nil?
  
      product = []
      product << prod.ext_product_id #ProductCode / ext_product_id
      product << 0               #QuantityInUnit

      total_qty = qty.nil? ? shop_prod.bundle_qty : qty.to_i

      product << total_qty 
      product << nil             #RxLabel
      product << nil             #OrderItemLineId 
      product << nil             #PatientNameItem
      product << nil               #DoctorNameItem
      product << 0               #RefillBalance
      product << nil             #RxRef
      product << 0               #RxAmount
      
      product.join("~")
    end
    
    def reconfigure_db(site_id)
      raise "Cannot establish connection. Site ID missing." if site_id.nil?

      isc_site = Site.find(site_id)
      establish_connection(isc_site.database_config.decrypted_attr)
    end
        
    def lists(options = {})
      page = options[:page] || 1
      products = page(page).order("created_at DESC")

      if options.has_key? :supplier_id
        products = products.where("supplier_id = ?", options[:supplier_id].to_i) unless options[:supplier_id].blank?
      end

      if options.has_key? :per_page
        products = products.per_page(options[:per_page].to_i) unless options[:per_page].blank?
      end

      if options.has_key? :q
        products = products.where("name LIKE ? OR id = ? OR ext_product_id LIKE ?", "%#{options[:q]}%", "#{options[:q]}", "%#{options[:q]}%") unless options[:q].blank?
      end
      
      products
    end
    
    def generate_uid(product, product_as)
      return (product_as.uid.nil? || product_as.uid == Product::UNASSOCIATED_UID)? (Product.get_max_uid + 1) : product_as.uid
    end
    
    def get_max_uid
      product = select("uid").where("uid IS NOT NULL").order("uid DESC").first
      return 0 if product.nil?
      return product.uid
    end
    
    def update_product_associations(product, as_prod, uid, all_products)
      # if there is no associated as product
      if (as_prod.nil?)
        associated_products = Product.where("uid = " + product.uid.to_s ) # find products that may be previously associated
        # if there are only 2 products that have the same product uid (including this product), disassociate both products.
        if (associated_products.count == 2) 
          associated_products.each do |ap|
            ap.update_attribute(:uid, Product::UNASSOCIATED_UID)
          end
        else # product to associate is also unassociated
          product.update_attribute(:uid, Product::UNASSOCIATED_UID)
        end
      # if there is a product to associate
      else
        # if product is unassociated & product to associate is associated, use the uid of the associate as product as the uid of the product
        if (uid == Product::UNASSOCIATED_UID && as_prod.uid != Product::UNASSOCIATED_UID)
          uid = as_prod.uid
        # if the product is already associated & the associated as product is unassociated, update the uid of the associate as product to the uid of the product 
        elsif (uid != Product::UNASSOCIATED_UID && as_prod.uid == Product::UNASSOCIATED_UID)
          as_prod.update_attribute(:uid, uid)
        # if both the product & associated as product are associated, update the uids of all the associated products of both the former & latter to the uid of the product
        elsif (uid != Product::UNASSOCIATED_UID && as_prod.uid != Product::UNASSOCIATED_UID)
          all_products = all_products - [ product ]
          all_products.each do |ap|
            ap.update_attribute(:uid, uid)
          end
        # if both the product & associated as product are unassociated, generate a new uid
        else
          uid = Product.maximum("uid") + 1
          as_prod.update_attribute(:uid, uid)
        end
      
        product.update_attribute(:uid, uid)
      end
      
      return product
    end
    
  end
  
  def supplier_name
    Supplier.find(self.supplier_id).company_name rescue nil
  end

  def get_suppliers
    if self.uid == Product::UNASSOCIATED_UID
      return Supplier.where("id = ?", self.supplier_id)
    end
    suppliers = Supplier.includes(:products).where("products.uid = ? AND products.uid > 0", self.uid)
    return suppliers
  end
  
  def show_expiry_date
    return '' if self.expiry_date.nil? || self.expiry_date.blank?
    dates = self.expiry_date.split(",")
    dates.uniq!
    dates.collect!{|d| d.to_date }
    dates.sort!
    return dates.first.strftime("%B %d, %Y") rescue ''
  end

end
