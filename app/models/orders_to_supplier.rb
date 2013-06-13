#encoding: utf-8
class OrdersToSupplier < ActiveRecord::Base
  establish_connection Rails.application.config.database_configuration["#{Rails.env}"]
  belongs_to :isc_order, :foreign_key => "order_id"
  serialize :order_string
  belongs_to :order_processing, :foreign_key => "order_processing_id"
  belongs_to :site

  scope :version2, lambda { where("oc_version=2") }
  self.per_page = 100
   
  class << self
    def check_duplicate(site_id, date="")
      duplicates = {}
      IscOrder.reconfigure_db(site_id)
      site = Site.find(IscOrder.site_id)
      date = date.blank? ? Time.current.to_date : date.to_date
      suppliers = Supplier.where("company_name IN (?)", Constant::SUPP_NAMES)

      suppliers.each do |supplier|
        duplicates["#{supplier.company_name}"] = []
        conditions = ["supplier_ids like '%#{supplier.id}%'"]
        conditions << "site_id = #{site.id}"
        conditions << "DATE_FORMAT(created_at, '%Y-%m-%d') >= '#{date}'"
        conditions << "oc_version=2"
  
        case supplier.company_name
        when Constant::SAVA
          conditions << "response_status like '%Success%'"
          otss = OrdersToSupplier.where(conditions.join(" AND ")).order("order_id")

          otss.each do |ots|
            if (ots.created_at < "2012-08-30 06:00:00".to_datetime) # if order was made before new API integration on 30 Aug, 2012, 2pm
              c = otss.select {|e| (e.order_id == ots.order_id && e.product_ids == ots.product_ids && e.order_string.to_s.split("\"ProductCode\"=>\"")[1].to_s.split("\",")[0] == ots.order_string.to_s.split("\"ProductCode\"=>\"")[1].to_s.split("\",")[0]) }
            else # if order was made after new API integration on 30 Aug, 2012, 2pm
              c = otss.select {|e| (e.order_id == ots.order_id && e.product_ids == ots.product_ids && e.order_string.to_s.split("itemsString' => \"")[1].to_s.split("\"")[0] == ots.order_string.to_s.split("itemsString' => \"")[1].to_s.split("\"")[0]) }
            end
            duplicates["#{supplier.company_name}"] << ots if (c.count > 1)
          end
        when Constant::WESTMEAD
          conditions << "response_status like '%ok%'"
          conditions << "split_flag not like '%r%' AND split_flag is not null"
          conditions << "oc_version=2"
          otss = OrdersToSupplier.where(conditions.join(" AND ")).order("order_id")

          otss.each do |ots|
            c = otss.select {|e| (e. order_id == ots.order_id && e.product_ids == ots.product_ids) }.count
            duplicates["#{supplier.company_name}"] += ots if (c > 1)
          end        
        end
      end
      
      duplicates
    end
    
    # "order_ids"=>{"30085601_r1"=>"30085601_r1"}, 
    # "30085601_r1"=>"30085601_r1", 
    # "checked_items"=>["126375-2247-30085601_r1"], 
    # "orderqty"=>{"126375-2247-30085601_r1"=>"2"}, 
    # "supplier"=>{"126375-2247-30085601_r1"=>"1"}
    def reorder_ots(params, site_id, testmode=true)
      IscOrder.reconfigure_db(site_id)
      by_supplier = {}
      otss = []
      
      params[:checked_items].each do |chk|
        split_qty = 0
        # 126294-3548-30085529_r1
        iop_id, product_id, order_flag_id = chk.split("-")
                            order_id_flag = params[:order_ids]["#{order_flag_id}"]
                          order_id, sflag = order_id_flag.split("_")
                              supplier_id = params[:supplier]["#{chk}"]
                                      qty = params[:orderqty]["#{chk}"].to_i
                                split_qty = params[:split_by]["#{chk}"].to_i rescue 0


        by_supplier[supplier_id] = {} if by_supplier[supplier_id].nil?
        by_supplier[supplier_id][order_id] = [] if by_supplier[supplier_id][order_id].nil?
        ots = {}

        ots[:order_id]     = order_id
        ots[:split_flag]   = sflag 
        ots[:product_ids]  = iop_id
        ots[:qty]          = qty
        ots[:site_id]      = session[:site_id]
        ots[:supplier_ids] = supplier_id
        ots[:prod_id]      = product_id

        if split_qty >= Constant::MIN_SPLIT_LIMIT
          boxes = (qty.to_f / split_qty.to_f).ceil
          r,n = Constant::R_FLAG, 0
          unless sflag.nil?
            r = sflag.to_s.first
            n = sflag.gsub(Constant::R_FLAG,'').to_i
          end
        
          for i in 1..boxes
            cloned_ots = ots.clone
          
            if n == 0
              new_sflag = nil
              order_id_custom = order_id
            else
              new_sflag =  "#{Constant::R_FLAG}#{n}"
              order_id_custom = order_id.to_s + "_#{new_sflag}"
            end
          
            cloned_ots[:split_flag] = new_sflag
            order_id_custom = 
            if i == boxes
              cloned_ots[:qty] = qty - ((boxes - 1) * split_qty.to_i)
              by_supplier[supplier_id][order_id] << cloned_ots
            else
              cloned_ots[:qty] = split_qty.to_i
              by_supplier[supplier_id][order_id] << cloned_ots
            end
            n += 1
          end
        else
          for_checking_indexs = []

          by_supplier[supplier_id][order_id].each_with_index do |chk_ots, indx|
            if chk_ots[:order_id] == order_id and chk_ots[:prod_id] == product_id           
              for_checking_indexs << indx
            end
          end
        
          if for_checking_indexs.length == 0
            by_supplier[supplier_id][order_id] << ots.clone
          elsif for_checking_indexs.length == 1
            by_supplier[supplier_id][order_id][for_checking_indexs.first][:qty] += ots.clone[:qty]
          else
            high = 0
            prev_qty = 0
            low_qty_indx = nil
            for_checking_indexs.each_with_index do |i, indx|
              if indx == 0
                prev_qty = by_supplier[supplier_id][order_id][i][:qty].to_i
                low_qty_indx = i
                next
              end 
            
              if by_supplier[supplier_id][order_id][i][:qty].to_i < prev_qty
                low_qty_indx = i
                prev_qty = by_supplier[supplier_id][order_id][i][:qty].to_i
              end
            end
          
            by_supplier[supplier_id][order_id][low_qty_indx][:qty] += ots.clone[:qty]
          end
        end
      end

      suppliers = {}
      by_supplier.keys.each do |key|
        suppliers["#{key}"] = {} if suppliers["#{key}"].nil?
      
        by_supplier["#{key}"].keys.each do |order_id|
          by_supplier["#{key}"]["#{order_id}"].each do |row|
            orderid_flag = "#{row[:order_id]}"
            orderid_flag += "_#{row[:split_flag]}" unless row[:split_flag].nil?
            suppliers["#{key}"]["#{orderid_flag}"] = [] if suppliers["#{key}"]["#{orderid_flag}"].nil?
            suppliers["#{key}"]["#{orderid_flag}"] << row
          end
        end 
      end
    
      suppliers.each do |supp_id, orders|
        orders.each do |orderid_flag, rows|
          unless rows.empty?
            order_id, flag = orderid_flag.split("_")
            order_params = OrdersToSupplier.generate_order_params(orderid_flag, rows, site_id, testmode)
            otss << OrdersToSupplier.create_ots(order_id, rows, order_params)
          end
        end
      end
      
      otss
    end
    
    def sent_orders(date, site_id)
      version2.where("site_id = ? AND (response_status like '%ok' OR response_status like '%Success%') AND DATE_FORMAT(created_at, '%Y-%m-%d') = ?", site_id, date).group("order_id")
    end
        
    def submitted_today
      ots = version2.where("order_processing_id IS NOT NULL AND DATE_FORMAT(created_at, '%Y-%m-%d') = ?", Time.current.strftime("%Y-%m-%d"))
      order_ids = ots.map(&:order_id).uniq
      order_ids
    end
    
    def generate_order_params(custom_order_id, temp_otss, site_id, test_mode = false)
      IscOrder.reconfigure_db(site_id.to_i)
      order_id, sflag = custom_order_id.split("_")
      order = IscOrder.find(order_id.to_i)
      site = Site.find(site_id.to_i)

      if test_mode
        username = "OPLTEST"
        password = "OPLTEST"
        firstname = "test firstname"
        lastname = "test lastname"
      else
        Rails.logger.info("**** Selecting the right site...")
        case site.sitecode.to_s
        when "BK"
          username = Constant::SAVA_BK_USERNAME
          password = Constant::SAVA_BK_PASSWORD
        when "PK"
          username = Constant::SAVA_PK_USERNAME
          password = Constant::SAVA_PK_PASSWORD
        when "KX", "WSH"
          username = Constant::SAVA_KX_USERNAME
          password = Constant::SAVA_KX_PASSWORD
        when "GP"
          username = Constant::SAVA_GP_USERNAME
          password = Constant::SAVA_GP_PASSWORD
        when "HB"
          username = Constant::SAVA_HB_USERNAME
          password = Constant::SAVA_HB_PASSWORD
        else
          Rails.logger.info("************ SITE: #{site.inspect} not supported")
          raise "************ SITE: #{site.inspect} not supported"
        end
  
        firstname = Helpers.clean_sava_field(order.isc_order_address.first_name)
        lastname = (order.isc_order_address.last_name + "様")
      end

      ord_params = {
        'userName'       => username,
        'password'       => password,
        'firstName'      => firstname,
        'lastName'       => lastname,
        'street'         => (Helpers.convert_multi_to_single_byte_alpha_num(order.isc_order_address.address_1.to_s + " " + order.isc_order_address.address_2.to_s)).to_s,
        'city'           => order.isc_order_address.city.to_s,
        'state'          => order.isc_order_address.state.to_s,
        'zip'            => (Helpers.convert_multi_to_single_byte_alpha_num(order.isc_order_address.zip)).to_s,
        'country'        => order.isc_order_address.country.to_s,
        'buyerOrderDate' => Time.current.strftime("%m/%d/%Y")
      }

      product_string = []
      temp_otss.each do |hash|
        puts "::::::::::::::::::::::"
        IscOrder.reconfigure_db(hash[:site_id])
        supplier = Supplier.find(hash[:supplier_ids].to_i)
        #product_hash = Product.product_string(hash[:product_ids], hash[:qty], hash[:site_id], supplier.id)
        Rails.logger.info("#{hash.inspect}")
        
        product_hash = Product.product_string(hash, supplier.id)
        Rails.logger.info("#{product_hash.inspect}")
        
        product_string << product_hash unless product_hash.nil?
      end

      ord_params['buyerOrderNo'] = custom_order_id
      ord_params['itemsString'] = product_string.join(":~:") 
       #Product.product_string(hash[:product_ids], hash[:qty], hash[:site_id])
        
      ord_params              
    end
    
    def notfiled_westmead(site_id, date)
      wm = Supplier.where("company_name='Westmead'").first
      return [] if wm.nil?
      version2.where("site_id = ? AND supplier_ids = ? AND response_status='ok' AND asset_id IS NULL AND DATE_FORMAT(created_at, '%Y-%m-%d')=?", site_id, wm.id, date).order("created_at DESC")
    end
    
    def new_westmead_orders(site_id)
      wm = Supplier.where("company_name='Westmead'").first
      return [] if wm.nil?
      version2.where("site_id = ? AND supplier_ids = ? AND response_status='ok' AND asset_id IS NULL AND DATE_FORMAT(created_at, '%Y-%m-%d') >= ?", site_id, wm.id, Constant::APP_STARTING_DATE).order("created_at DESC")
    end
    
    def create_ots(custom_order_id, temp_otss = [], order_params = nil)
      valid_keys = ["order_id", "split_flag", "product_ids", "site_id", "supplier_ids", "order_string", "response_status", "order_procesing_id"]
      product_ids, supplier_ids = [], []
      order_id, sflag = custom_order_id.split("_")

      ots = OrdersToSupplier.new 
      ots.order_id = order_id
      ots.oc_version = 2
      
      ots.order_string = { :order_params => order_params } unless order_params.nil?

      temp_otss.each do |hash|
        ots.split_flag = hash[:split_flag]
        ots.site_id = hash[:site_id].to_i
        product_ids << hash[:product_ids].to_i
        supplier_ids << hash[:supplier_ids].to_i  
      end
      ots.product_ids = product_ids.join(",") 
      ots.supplier_ids = supplier_ids.join(",")

      return ots if ots.save
      return nil
    end    

    def create_with_ordproc(order_processings, order_params = nil, response, product_hash)
      Delayed::Worker.logger.info("create_with_ordproc.....")
      isc_order_products_ids = []
      product_hash.each {|ph| isc_order_products_ids << ph[:isc_order_product] }
      op = order_processings.first

      ordtoproc = OrdersToSupplier.new
      ordtoproc.site_id = op.site_id
      ordtoproc.order_id = op.order_id
      ordtoproc.split_flag = op.split_flag
      ordtoproc.supplier_ids = op.supplier_id
      ordtoproc.product_ids = isc_order_products_ids.join(",")
      ordtoproc.order_string = { :order_params => order_params } unless order_params.nil?
      ordtoproc.order_processing_id = op.id
      ordtoproc.oc_version = 2

      unless response.nil?
        if response == Net::HTTPOK
          ordtoproc.response_status = response.body
        else
          ordtoproc.response_status = response
        end
      end
      ordtoproc.save!

      #updating order_processings created_at to current date
      order_processings.each {|op| op.update_attribute(:created_at, Time.current) }
      
      Delayed::Worker.logger.info("done with create_with_ordproc..")
      ordtoproc
    end
        
    def deprecated_create_with_ordproc(order_processings, order_params = nil, response, product_hash)
      order_processings = [order_processings] if !order_processings.is_a? Array 
      puts order_processings.inspect
      
      isc_order_products_ids = []
      product_hash.each {|ph| isc_order_products_ids << ph[:isc_order_product] }
      
      order_processings.each do |op|
        ordtoproc = OrdersToSupplier.where("site_id = ? AND order_processing_id = ?",op.site_id, op.id).first || OrdersToSupplier.new
        ordtoproc.site_id = op.site_id
        ordtoproc.order_id = op.order_id
        ordtoproc.split_flag = op.split_flag
        ordtoproc.supplier_ids = op.supplier_id
        ordtoproc.product_ids = isc_order_products_ids.join(",")
        ordtoproc.order_string = { :order_params => order_params } unless order_params.nil?
        ordtoproc.order_processing_id = op.id
        
        unless response.nil?
          if response == Net::HTTPOK
            ordtoproc.response_status = response.body
            puts response.body.class
          else
            ordtoproc.response_status = response            
          end
        end
        
        ordtoproc.save!
        ordtoproc
      end
    end
    
  end

  def createdat
   self.created_at.strftime("%Y-%m-%d")
  end
  
  def get_suppliers_name
    ids = self.supplier_ids.split(",")
    supps = Supplier.where("id IN (?)", ids)
    supps.map(&:company_name).join(", ")
  end

  def order_product
    ioprod = IscOrderProduct.find_by_orderprodid(self.product_ids.to_i) rescue nil
    ioprod    
  end
  
  def product
    ioprod = IscOrderProduct.find_by_orderprodid(self.product_ids.to_i)
    shop_prod = ShopProduct.where("isc_product_id=? AND site_id = ?", ioprod.ordprodid, self.site_id).first
    prod = Product.find(shop_prod.product_id) rescue nil
    prod    
  end
  
  def get_product_string
    ioprod = IscOrderProduct.find_by_orderprodid(self.product_ids.to_i)
    shop_prod = ShopProduct.where("isc_product_id=? AND site_id = ?", ioprod.ordprodid, self.site_id).first
    prod = Product.find(shop_prod.product_id)

    product = []

    unless prod.nil?
      product << prod.ext_product_id #ProductCode / ext_product_id
      product << 0               #QuantityInUnit
      
      #TODO : recompute the qty
      product << self.qt.qty     # Quantity 
      product << nil             #RxLabel
      product << nil             #OrderItemLineId 
      product << nil             #PatientNameItem
      product << nil               #DoctorNameItem
      product << 0               #RefillBalance
      product << nil             #RxRef
      product << 0               #RxAmount
    end
    
    product.join("~")  
  end

  def order_string_product_ids
    return nil if self.order_string.nil?
    prod_codes = []
    order_params = self.order_string[:order_params]

    unless order_params.nil?
      item_rows = order_params["itemsString"].split(":~:") rescue []
      item_rows.each do |row|
        prod_codes << row.split("~")[0] rescue nil
      end
    end

    return prod_codes.join(",")
  end  
end
