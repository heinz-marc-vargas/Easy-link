class ShopProduct < ActiveRecord::Base
  belongs_to :product
  belongs_to :site
  belongs_to :supplier
  #belongs_to :isc_products, :foreign_key => "productid"
  belongs_to :isc_product, :foreign_key => "isc_product_id"

  
  validates :site_id, :presence => true
  validates :product_id, :presence => true
  validates :supplier_id, :presence => true
  validates :bundle_qty, :presence => true
  self.per_page = Constant::PERPAGE
  
  establish_connection Rails.application.config.database_configuration["#{Rails.env}"]
  
  simple_audit do |sp_record|
    {
        :supplier_id => sp_record.supplier_id,
        :product_id => sp_record.product_id,
        :site_id => sp_record.site_id,
        :isc_product_id => sp_record.isc_product_id,
        :bundle_qty => sp_record.bundle_qty,
        :username_method => User.current,
        :product => sp_record.product,
        :site => sp_record.site
    }
  end
  
  class << self
    def reconfigure_db(site_id)
      raise "Cannot establish connection. Site ID missing." if site_id.nil?

      isc_site = Site.find(site_id)
      establish_connection(isc_site.database_config.decrypted_attr)
      self.reset_column_information
    end
          
    def lists(options = {})
      site_id = nil
      page = options[:page] || 1
      products = page(page).order("shop_products.created_at DESC").where("shop_products.product_id IS NOT NULL").includes(:product, :site, :supplier)

      if options.has_key? :site_id
        site_id = options[:site_id].to_i
        products = products.where("shop_products.site_id = ?", options[:site_id].to_i) unless options[:site_id].blank?
      end
      
      if options.has_key? :supplier_id
        products = products.where("shop_products.supplier_id = ?", options[:supplier_id].to_i) unless options[:supplier_id].blank?
      end

      if options.has_key? :per_page
        products = products.per_page(options[:per_page].to_i) unless options[:per_page].blank?
      end
      
      if options.has_key? :q
        products = products.where("products.name like ? OR shop_products.id = ? OR isc_product_id like ?", "%#{options[:q]}%", "#{options[:q]}", "#{options[:q]}") unless options[:q].blank?
      end
      
      if options.has_key? :pkgtype
        products = products.where("shop_products.isc_product_id IS NULL") if options[:pkgtype] == 'bundle'
        products = products.where("shop_products.isc_product_id IS NOT NULL").order("shop_products.isc_product_id DESC") if options[:pkgtype] == 'combi'
      end

      unless site_id.nil?
        IscOrder.reconfigure_db(site_id) unless site_id.nil?
        isc_product_ids = products.map(&:isc_product_id)
        group_isc_products = IscProduct.where("productid IN (?)", isc_product_ids).group_by(&:productid)

        products.each do |p|
          if p.isc_product_id > 0
            p.isc_product = group_isc_products[p.isc_product_id].first rescue nil
          end
        end
      end
      
      products
    end

    def quick_create_with_site(product, site, qty=1, isc_product_id=nil)
      return nil if product.nil?
      return nil if site.nil?

      sp                = ShopProduct.new
      sp.supplier_id    = product.supplier.id
      sp.product_id     = product.id
      sp.site_id        = site.id
      sp.isc_product_id = (isc_product_id || get_next_isc_product_id(site))
      sp.bundle_qty     = qty
      sp.save!
    end
    
    def quick_create(product, supplier)
      return nil if product.nil?
    
      product.sites.each do |site|
        sp                = ShopProduct.new
        sp.supplier_id    = product.supplier_id
        sp.product_id     = product.id
        sp.site_id        = site.id
        sp.isc_product_id = get_next_isc_product_id(site)
        sp.bundle_qty     = 1
        sp.default_supplier_id = supplier.id  unless supplier.nil?
        sp.save!
      end
    end
    
    def set_default_supplier(shop_product_id, site_id, supplier_id)
      shop_product = ShopProduct.find(shop_product_id)
      shop_products = ShopProduct.where("isc_product_id = ? and site_id = ?", shop_product.isc_product_id, site_id)
      OrderProcessing.remove_byproduct_id(shop_products.map(&:product_id))
    
      if shop_products.length > 0  #combi
        shop_products.each do |sp|
          if sp.product.uid > 0
            products = Product.where("uid = ? AND supplier_id = ?", sp.product.uid, supplier_id)
            unless products.empty?
              selected_prod = products.first
              sp.product_id = selected_prod.id
              sp.supplier_id = selected_prod.supplier_id
              sp.save
            end
          else
            sp.product_id = sp.product_id
            sp.supplier_id = sp.supplier_id
            sp.save
          end
        end
      else #single shop_product
        if shop_product.product.uid > 0
          products = Product.where("uid = ? AND supplier_id = ?", shop_product.product.uid, supplier_id)
          unless products.empty?
            selected_prod = products.first
            shop_product.product_id = selected_prod.id
            shop_product.supplier_id = selected_prod.supplier_id
            shop_product.save
          end    
        end
      end
    
      shop_product.reload
      return shop_product
    end
  
    def check_same_similar_products_exists(product_id, site_id, isc_product_id)
      same_similar_products = {}
      product = Product.find(product_id)
    
      same_similar_products[:same_product] = ShopProduct.where("site_id = ? AND isc_product_id = ? AND product_id = ?", site_id, isc_product_id, product_id)
      same_similar_products[:similar_sup_product] = []
  
      if (same_similar_products[:same_product].empty? && product.uid != 0)
        similar_products = Product.find(:all, :conditions => { :uid => product.uid.to_i })
  
        similar_products.each do |simp|
          sps = ShopProduct.where("site_id = ? AND isc_product_id = ? AND product_id =?", site_id, isc_product_id, simp.id)
          same_similar_products[:similar_sup_product] <<  sps unless sps.empty?
        end
      end
    
      return (same_similar_products[:same_product].empty? && same_similar_products[:similar_sup_product].empty?)
    end
    
    def add_bundle_to_sites(site_ids, shopproduct)
      site_ids.each do |site_id|
        site = Site.find(site_id) rescue nil
        next if site.nil?
        
        clone = shopproduct.clone
        clone.site_id = site_id
        clone.isc_product_id = ShopProduct.get_next_isc_product_id(site)
        clone.save!
      end
    end
    
    def add_combi_to_sites(site_ids, product_ids, bundle_qtys)
      site_ids.each do |sid|
        site = Site.find(sid.to_i)
        isc_product_id = ShopProduct.get_next_isc_product_id(site)
        product_ids.each do |pid|
          indx  = product_ids.index(pid)
          product = Product.find(pid.to_i)
          ShopProduct.quick_create_with_site(product, site, bundle_qtys[indx], isc_product_id)
        end
      end
    end
    
  end
  
  def default_supplier
    sup = Supplier.find(self.default_supplier_id) rescue nil
    return '' if sup.nil?
    return sup.company_name
  end

  private
  def self.get_next_isc_product_id(site)
    return nil if site.nil?
    IscOrder.reconfigure_db(site.id)
    last = IscProduct.last
    return 1 if last.nil? || last.productid.nil? #hack to initialize the counting
    return last.productid + 1
  end

end
