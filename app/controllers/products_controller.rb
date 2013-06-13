class ProductsController < ApplicationController
  before_filter :authenticate_user!

  def set_default_supplier
    render :nothing => true && return if params[:supplier_id].blank?
    expire_fragment("#{params[:site_id]}-preview_supplier_order_data")
    
    @sp = nil
    if (!params[:id].blank? && !params[:site_id].blank? && !params[:supplier_id].blank?)
      @sp = ShopProduct.set_default_supplier(params[:id], params[:site_id], params[:supplier_id])
    end
    
    respond_to do |format|
      format.js
    end
  end
  
  def insert_product
    @error = nil
    
    begin
      product = Product.find(params[:product][:product_id].to_i)
      same_similar_products_dont_exists = ShopProduct.check_same_similar_products_exists(product.id, params[:product][:site_id].to_i, params[:product][:isc_product_id].to_i)
      Rails.logger.info("&&&&&&&&& " + same_similar_products_dont_exists.inspect)
      shop_product = nil
      saved = false
  
      if (same_similar_products_dont_exists)
        if (params[:product][:isc_product_id] != nil && params[:product][:qty] != nil)
          shop_product = ShopProduct.create(:supplier_id => product.supplier_id, :product_id => product.id, :site_id => params[:product][:site_id].to_i, :isc_product_id => params[:product][:isc_product_id].to_i, :bundle_qty => params[:product][:qty].to_i)
        else
          raise "Please enter ISC Product ID or Bundle Quantity."
        end
      else
        raise "Same / similar product exists."
      end
    rescue Exception => e
      @error = e.message.to_s
    end
    
    respond_to do |format|
      format.js
    end 
  end
  
  def insert
    @suppliers = Supplier.active_suppliers
    @products = Product.order("name ASC")
    
    respond_to do |format|
      format.html
      format.js
    end
  end

  def supplier
    assoc = Product.where("uid IS NOT NULL AND uid > 0").order("uid ASC")
    @associated = assoc.group_by(&:uid) 
  end
  
  def unassociated
   respond_to do |format|
      format.html
      format.js
      format.json { render json: UnassociatedDatatable.new(view_context) }
    end    
  end

  def show_comment_form
    @object = params[:klass].camelize.constantize.find(params[:id].to_i) rescue nil
  end

  def add_comment
    @object = params[:klass].camelize.constantize.find(params[:id]) rescue nil
    @object.update_attribute(:staff_comments, params[:comments])

   respond_to do |format|
      format.html { render :partial => "/products/add_comment" }
      format.js
    end    

  end  
    
  def show_note_form
    @product = Product.where("ext_product_id = ?", params[:sku]).first    
  end
  
  def add_note
    @product = Product.find(params[:id]) rescue nil
    @product.update_attribute(:notes, params[:notes])
  end
  
  def stocks
    supps = ["SAVA", "Westmead"]
    @suppliers = Supplier.where("company_name IN (?)", supps)
    @stock_data = []
    @error_message = nil
    @expiring_sku = []
    @expiring_products = []
    @lowstock_products = []
    
    if request.post?
      begin
        raise "You have not selected a file." if params[:file].nil?
        file, filename = params[:file], params[:file].original_filename
        raise "Invalid file format" if !Constant::XLS_CONTENT_TYPES.include?(file.content_type.to_s)
        raise "Please select a supplier" if params[:supplier_id].nil?

        #ready to write the file...
        #fpath = Rails.root.join('data', 'stocks')
        fpath = Rails.root.join(Constant::DIRS[:data], Constant::DIRS[:stocks])
        FileUtils.mkdir_p(fpath) if !File.exists? fpath
        fpath = fpath.join(filename)
        File.open((fpath), 'wb'){|f| f.write(file.read)}
        
        results = XlsParser.read_stock_data(fpath, params[:supplier_id])
        @stock_data = results[:stock_data]
        @expiring_products = results[:expiring]
        @lowstock_products = results[:lowstocks]
        
        @expiring_products.each do |prod, expiry_date|
          @expiring_sku << prod.ext_product_id
        end
        @expiring_sku.uniq!
      rescue Exception => e
        @error_message = e.message.to_s
      end
    end
    
    @jobs = Job.where("queue = 'mage' AND failed_at IS NULL").count
  end

  def thresholds
    @threshold_data = []
    @error_message = nil
    
    if request.post?
      begin
        raise "You have not selected a file." if params[:file].nil?
        file, filename = params[:file], params[:file].original_filename
        raise "Invalid file format" if !Constant::XLS_CONTENT_TYPES.include?(file.content_type.to_s) 

        #ready to write the file...
        #fpath = Rails.root.join('data', 'thresholds')
        fpath = Rails.root.join(Constant::DIRS[:data], Constant::DIRS[:threshold])
        FileUtils.mkdir_p(fpath) if !File.exists? fpath
        fpath = fpath.join(filename)

        File.open((fpath), 'wb') do |f|
          f.write(file.read)
        end
        @threshold_data = XlsParser.read_threshold_data(fpath)
      rescue Exception => e
        @error_message = e.message
      end
    end
  end
  
  def index
    @products = Product.lists(params)
    @suppliers = Supplier.active_suppliers

    respond_to do |format|
      format.html
      format.js
      format.json { render json: ProductsDatatable.new(view_context) }
    end
  end

  def show
    @product = Product.find(params[:id])
  end
  
  def shop
    if !params.has_key? :site_id
      params[:site_id] = session[:site_id]
    end

    IscOrder.reconfigure_db(session[:site_id])
    @products = ShopProduct.lists(params)
    @sites = current_user.sites
    @suppliers = Supplier.active_suppliers
    @by_supplier_id = @suppliers.group_by(&:id)

    @show_mg_shop_products = Constant::MG_SITE_IDS.include?(params[:site_id].to_i)
    if (@show_mg_shop_products)
      @mg_product_list = Mage.get_product_list
    end  
    respond_to do |format|
      format.html
      format.js
    end    
  end

  def new
    @product = Product.new
    @products = Product.all
    @sites = current_user.sites
    @suppliers = Supplier.active_suppliers
    
    respond_to do |format|
      format.html
      format.js
    end
  end

  def newbundle
    @shopproduct = ShopProduct.new
    @products = Product.all
    @sites = current_user.sites
    @suppliers = Supplier.all.group_by(&:id)
    
    respond_to do |format|
      format.html
      format.js
    end
  end

  def newcombi
    @shopproduct = ShopProduct.new
    @products = Product.order("name ASC")
    @suppliers = Supplier.all.group_by(&:id)
    @sites = current_user.sites
    
    respond_to do |format|
      format.html
      format.js
    end
  end

  def createcombi
    @shopproduct = ShopProduct.new
    begin
      copy_product = params[:product]
    
      raise t('errors.product_not_selected') if (params[:product] - [""]).blank?
      raise t('errors.must_select_all_relevant_products') if params[:product].include?("")
      raise t('errors.must_select_more_than_one_product') if ( (params[:product] - [""]).count < 2 )
      raise t('errors.must_be_different_products') if !copy_product.uniq!.nil?
      raise t('errors.need_bundle_qty') if params[:bundle_qty].blank?
      raise t('errors.must_fill_in_all_bundle_qty') if params[:bundle_qty].include?("")
      raise t('errors.need_sites') if params[:sites].nil? || params[:sites].empty?

      respond_to do |format|
        if @shopproduct.errors.empty?
          ShopProduct.add_combi_to_sites(params[:sites], params[:product], params[:bundle_qty])

          format.html { redirect_to shop_products_url } 
          format.js
        end
      end
    rescue Exception => e
      @shopproduct.errors.add(:base, e.message)
      
      respond_to do |format|
        format.js { @shopproduct }
      end
    end
    
  end
    
  def edit
    @product = Product.find(params[:id])
    @products = Product.all
    @sites = current_user.sites
    @suppliers = Supplier.active_suppliers
    @product_uid = nil
    unless @product.uid.nil?
      @product_uid = Product.find(@product.uid) if @product.uid.to_i > 0
    end    
    
    respond_to do |format|
      format.html
      format.js
    end    
  end

  def editshop
    @shopproduct = ShopProduct.find(params[:id])
    IscOrder.reconfigure_db(@shopproduct.site_id)
    @isc_product = IscProduct.find(@shopproduct.isc_product_id)
    
    if @shopproduct.product.uid > 0
      prods = Product.where("uid = ?", @shopproduct.product.uid)
      supp_ids = prods.map(&:supplier_id).uniq
      @suppliers = Supplier.where("id IN (?)", supp_ids)
    else
      supp_ids = [ @shopproduct.product.supplier_id ]
      @suppliers = Supplier.where("id IN (?)", supp_ids) 
    end
    @products = Product.includes(:supplier) - [@shopproduct.product]
    @sites = current_user.sites
    #@suppliers = Supplier.active_suppliers
    
    respond_to do |format|
      format.html
      format.js
    end    
  end
  
  def createbundle
    @shopproduct = ShopProduct.new(params[:shop_product])
    begin      
      raise t('errors.product_not_selected') if params[:shop_product][:product_id].blank?
      raise t('errors.need_bundle_qty') if params[:shop_product][:bundle_qty].blank?
      raise t('errors.need_sites') if params[:sites].nil? || params[:sites].empty?
    
      unless params[:shop_product][:product_id].blank?
        product = Product.find(params[:shop_product][:product_id])
        @shopproduct.supplier_id = product.supplier_id
      end
      
      site_ids = params[:sites] - [@shopproduct.site_id.to_s]
    
      respond_to do |format|
        ShopProduct.add_bundle_to_sites(site_ids, @shopproduct)
        
        format.js
      end
    rescue Exception => e
      @shopproduct.errors.add(:base, e.message)
    end
  end

  def create # used by add supplier product
    @product = Product.new(params[:product])
    @suppliers = Supplier.active_suppliers
    
    begin
      product_as = nil
      unless params[:product_as].blank?
        product_as = Product.find(params[:product_as])
        raise "Product & Associated product cannot be from the same supplier" if product_as.supplier_id == @product.supplier_id
      end
    
      respond_to do |format|
        if @product.save    
          unless product_as.nil?
            uid = Product.generate_uid(@product, product_as)
            @product.update_attribute(:uid, uid)
            product_as.update_attribute(:uid, uid) unless uid == product_as.uid
          end
        
          unless params[:sites].nil?
            params[:sites].each do |site_id|
              site = Site.find(site_id)
              @product.sites << site unless site.nil?
            end
          end
        
          #adding to shop_products
          unless params[:add_shop_products].nil?
            default_supp = Supplier.find(params[:default_supplier_id]) rescue nil
            ShopProduct.quick_create(@product, default_supp)
          end
        
          format.html { redirect_to(@product) }
          format.js
        end
      end
    rescue Exception => e
      respond_to do |format|
        @product.errors.add(:base, e.message)
        format.js { @product }
      end
    end
  end

  def updateshop
    @shopproduct = ShopProduct.find(params[:id])
    begin
      raise t("errors.need_bundle_qty") if params[:shop_product][:bundle_qty].blank?
      
      respond_to do |format|
        params[:shop_product][:product_id] = params[:product_id] unless params[:product_id].blank?
        Rails.logger.info("$$$")
        if @shopproduct.update_attributes(params[:shop_product])
          Rails.logger.info("###")
          format.html { redirect_to shop_products_url, :notice => "Shop Product successfully updated." }
          format.js
        end
      end
    rescue Exception => e
      respond_to do |format|
        @shopproduct.errors.add(:base, e.message)
        format.js { @shopproduct }
      end
    end 
  end
    
  def update  # used by edit supplier product
    @product = Product.find(params[:id])
    
    begin
      raise t("errors.need_product_name") if params[:product][:name].blank?
      raise t("errors.need_product_sku") if params[:product][:ext_product_id].blank?
      raise t("errors.need_product_supplier") if params[:product][:supplier_id].blank?
      
      as_prod = (!params[:product_as].blank?)? Product.find(params[:product_as]) : nil
      
      uid = @product.uid
      all_products = nil
      unless as_prod.nil?
        temp_uids = [as_prod.uid, uid] - [ Product::UNASSOCIATED_UID ]
        
        if temp_uids.blank?
          all_products = [ @product, as_prod ]
        else
          all_products = Product.where("uid IN (" + temp_uids.join(",") + ") OR id = " + @product.id.to_s)
        end
        
        dup_supplier = 0
        if params[:product][:supplier_id].to_i == @product.supplier_id
          dup_supplier = all_products.group_by {|e| e.supplier_id}.select { |k,v| v.size > 1}.count
        else
          all_supplier_ids = (all_products - [ @product ]).collect { |ap| ap.supplier_id }
          
          if (all_supplier_ids.include?params[:product][:supplier_id].to_i)
            dup_supplier = 1
          end
        end
        raise t("errors.need_different_supplier") if (dup_supplier > 0)
      end
      
      @product = Product.update_product_associations(@product, as_prod, uid, all_products)

      respond_to do |format|
        if @product.update_attributes(params[:product])
          unless params[:sites].nil?
            unless params[:sites].empty?
              @product.sites = []
              params[:sites].each do |site_id|
                site = Site.find(site_id)
                @product.sites << site unless site.nil?
              end
            end
          end
          format.html { redirect_to products_url, :notice => "Product successfully updated" }
          format.js
        end
      end
    rescue Exception => e
      respond_to do |format|
        @product.errors.add(:base, e.message)
        format.html { render :action => :edit }
        format.js { @product }
      end
    end
  end

  def destroy
    @product = Product.find(params[:id])
    if @product.uid != 0
      associated_products = Product.where("uid = " + @product.uid.to_s + " AND id != " + @product.id)
      if (associated_products.count == 1)
        associated_product.first.update_attribute(:uid, 0)
      end
    end
    @product.destroy

    respond_to do |format|
      format.html { redirect_to products_url }
      format.js
    end
  end

  def deleteshop
    @sp = ShopProduct.find(params[:id])
    @sp.destroy

    respond_to do |format|
      format.html { redirect_to products_url }
      format.js
    end
  end
  
  def cart_middle_layer
    @sites = Site.where("cart_type = 2")
    
    if (params[:site_id].nil? == false)
      site = @sites.select { |s| s.id == params[:site_id].to_i}
      raise "Invalid site id" if site.empty?
      session[:site_id] = params[:site_id].to_i unless site.empty?
    else
      session[:site_id] = (session[:site_id].nil?)? @sites[0].id : session[:site_id]
    end
    
    IscOrder.reconfigure_db(session[:site_id])
    @isc_products = IscProduct.lists(params)
  end
  
  def new_cart_product
    @isc_products = IscProduct.new
    @sites = current_user.sites.where("cart_type = 2")
    
    respond_to do |format|
      format.html
      format.js
    end
  end
  
  def insert_to_middle_layer
    @error = ""
    
    begin
      raise t("errors.need_cart_product_id") if params[:isc_product][:productid].blank?
      raise t("errors.need_cart_product_name") if params[:isc_product][:prodname].blank?
      raise t("errors.need_cart_product_code") if params[:isc_product][:prodcode].blank?
      raise t("errors.need_cart_site") if params[:sites].blank?
      
      IscProduct.create_cart_product(params[:sites][0].to_i, params[:isc_product][:prodcode], params[:isc_product][:prodname], params[:isc_product][:productid].to_i)
    rescue Exception => e
      @error = e.message
    end
  end
  
  def editcart
    @isc_product = IscProduct.find(params[:id])
    
    respond_to do |format|
      format.html
      format.js
    end    
  end
  
  def updatecart
    @isc_product = IscProduct.find(params[:id])
    Rails.logger.info(params.inspect)
    
    begin
      raise t("errors.need_cart_product_name") if params[:isc_product][:prodname].blank?
      raise t("errors.need_cart_product_code") if params[:isc_product][:prodcode].blank?
      
      respond_to do |format|
        if @isc_product.update_attributes(params[:isc_product])
          format.html { redirect_to cart_middle_layer_products_url, :notice => "Cart Product successfully updated." }
          format.js
        end
      end
    rescue Exception => e
      respond_to do |format|
        @isc_product.errors.add(:base, e.message)
        format.js { @isc_product }
      end
    end    
  end
  
  def deletecart
    @ip = IscProduct.find(params[:id])
    @ip.destroy

    respond_to do |format|
      format.html { redirect_to cart_middle_layer_products_url }
      format.js
    end
  end
  
end
