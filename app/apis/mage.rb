# encoding: utf-8
#require 'magento_api'
class Mage
  debug_mode = Rails.env == "development" ? true : false
  @magento = MagentoAPI.new(CONFIG[:magento_pkhost], CONFIG[:magento_user], CONFIG[:magento_key], :debug => debug_mode)
    
  def self.populate_order_processings(order_ids = nil)
    Rails.logger.info("Populating OrderProcessings records...#{order_ids}")    
    site = Site.find_by_sitecode(Constant::PKY_CODE)

    if order_ids.nil?
      mage_orders = @magento.call("sales_order.list", :status => "processing")
      order_ids   = mage_orders.collect{|o| o['increment_id']}
    else
      order_ids   = order_ids.split(",")  
    end
     
    result = {}
    result[:created_lines] = []
    result[:missing_lines] = []
    
    orders = @magento.call("order.info", "#{order_ids.join(',')}")
    orders = [orders] if orders.is_a? Hash

    orders.each do |order|
      order_id = order['increment_id']
      
      unless order.nil?
        isc_order = create_update_iscorder(order, site.id)
        next if order['status'] != "processing"
        
        order['items'].each do |item|
            next if item['product_type'] == "bundle"
            Rails.logger.info("item_id= #{item['item_id']}")

            sp = ShopProduct.where("isc_product_id = ? AND site_id = ?", item['product_id'], site.id)
            Rails.logger.info("sp = #{sp.length}")
            
            unless sp.empty?
              product_suppliers = []
              sp.each do |sproduct|
                next if sproduct.product.nil?
                
                if sproduct.product.uid.to_i > 0
                  products = Product.where("uid = ? AND supplier_id != 2", sproduct.product.uid.to_i)
                  product_suppliers << Supplier.where("id IN (?)", products.map(&:supplier_id)).map(&:id)
                else
                  product_suppliers << [sproduct.product.supplier.id] unless sproduct.product.nil?
                end
              end

              init_supp_ids = [sp.first.supplier.id] #product_suppliers.first
              product_suppliers.each do |arr|
                init_supp_ids = init_supp_ids & arr
              end
              init_supp_ids = [sp.first.supplier.id] if init_supp_ids.empty?

              combi_id = nil
              sp.each do |sproduct|
                #Rails.logger.info("sproduct= #{sproduct.inspect} \n")
                next if sproduct.product.nil?

                total_qty = (item['qty_ordered'].to_i * sproduct.bundle_qty.to_i) rescue 0
                dup_orderproc = OrderProcessing.where("oc_version=2 AND (sent IS NULL OR sent=0) AND order_id = ? AND isc_product_id = ? AND product_id = ? AND site_id = ?", 
                                order['increment_id'], item['product_id'], sproduct.product_id, site.id)
                #Rails.logger.info("dup_orderproc = #{dup_orderproc}")
                  
                if dup_orderproc.empty?
                  orderproc                =  OrderProcessing.new
                  orderproc.order_id       = order['increment_id']
                  orderproc.product_id     = sproduct.product_id rescue nil
                  orderproc.isc_product_id = item['product_id']
                  orderproc.qty            = total_qty
                  orderproc.supplier_ids   =  init_supp_ids.uniq.join(",")
                  orderproc.split_by_val   = nil
                  orderproc.site_id        =  site.id
                  orderproc.oc_version     = 2
                  orderproc.combi_id       = combi_id
                  orderproc.supplier_id    =  sproduct.supplier_id.to_i
                  orderproc.item_sku       = item['sku']
                  orderproc.item_id        = item['item_id']
                  orderproc.item_name      = item['name']
                  orderproc.save!
                  
                  combi_id = sp.length > 1 ? orderproc.id: nil
                  result[:created_lines] << item
                end
              end
            else
              result[:missing_lines] << item
            end
          
        end
      end
    end
    
    result
  end
  
  def self.change_status(order_ids, status, send_email = 1)
    Delayed::Worker.logger.info("DELAYED: Mage.change_status(#{order_ids}, #{status}, #{send_email} )")
    
    begin
      order_ids = [order_ids] if !order_ids.is_a? Array
      mage_status = Helpers.isc_to_mage_ordstatus(status.to_i)
      IscOrder.reconfigure_db(18)

      order_ids.each do |order_id|
        Delayed::Worker.logger.info("DELAYED mage_status: #{mage_status} )")
        comment = ""
        order = IscOrder.find(order_id)
        mage_status = Helpers.isc_to_mage_ordstatus(status)
 
        if [2,3].include?(order.ordstatus) 
          isd = IscShipmentData.where("order_id=?", order_id).group("tracking_num")
          unless isd.nil?
            comment = "[お荷物追跡番号]\n"
            isd.each do |isd|
              comment += "#{isd.tracking_num}\n"
            end
          end 
        end

        comment += item_rows(order.order_info['items'])
        
        @magento.call("order.addComment", order_id, mage_status, comment, send_email)
      end
    rescue Exception => e
      RedMailer.delay(:queue => "emails").notifier("Error: Mage.send_email(#{order_ids}, #{status}, #{send_email}) - #{e.message}")
    end
  end

  def self.send_email(order_ids, site_id, send_email = 1)
    begin
      Rails.logger.info("site_id #{site_id}")
      IscOrder.reconfigure_db(site_id)
      if !order_ids.is_a? Array
        order_ids = [order_ids]
      end

      orders = IscOrder.where("orderid IN (?)", order_ids)

      orders.each do |order|
        comment = ""
        mage_status = Helpers.isc_to_mage_ordstatus(order.ordstatus.to_i)
        
        if [2,3].include?(order.ordstatus)
          isd = IscShipmentData.where("order_id=?", order.orderid).group("tracking_num")
          unless isd.nil?
            comment = "[お荷物追跡番号]\n"
            isd.each do |isd|
              comment += "#{isd.tracking_num}\n"
            end
          end 
        end

        comment += item_rows(order.order_info['items'])
        
        @magento.call("order.addComment", order.orderid, mage_status, comment, send_email)
      end
    rescue Exception => e
      RedMailer.delay(:queue => "emails").notifier("Error: Mage.send_email(#{order_ids}, #{site_id}) - #{e.message}")
    end
  end

  def self.update_status(order_id, site_id, ordstatus, send_email = 1)
    begin
      IscOrder.reconfigure_db(site_id)
      order = IscOrder.find(order_id)
      mage_status = Helpers.isc_to_mage_ordstatus(ordstatus.to_i)

      comment = ""
      
        if [2,3].include?(order.ordstatus)
          isd = IscShipmentData.where("order_id=?", order.orderid).group("tracking_num")
          unless isd.nil?
            comment = "[お荷物追跡番号]\n"
            isd.each do |isd|
              comment += "#{isd.tracking_num}\n"
            end
          end 
        end 

        comment += item_rows(order.order_info['items'])

      @magento.call("order.addComment", order.orderid, mage_status, comment, send_email)
    rescue Exception => e
      RedMailer.delay(:queue => "emails").notifier("Error: Mage.update_status(#{order_id}, #{site_id}, #{ordstatus}) - #{e.message}")
    end
  end
  
  def self.create_shipment(order_id, site_id, send_email = 1)
    include_comment = 0
    comment = ""
    
    begin
      IscOrder.reconfigure_db(site_id)
      order = IscOrder.find(order_id)
      mage_shipments = order.magento_shipments
      shipment_ids = mage_shipments.map(&:shipment_id)
      
      magento_tracks = []
      shipment_ids.each do |ship_id|
        info = @magento.call("order_shipment.info", ship_id.to_s)
        unless info.nil?
          info['tracks'].each do |t|
            magento_tracks << t['track_number'].to_s.strip
          end
        end
      end
      
      isd_grp = IscShipmentData.where("order_id=?", order_id).group_by(&:tracking_num)

      isd_grp.keys.each do |track|
        isd = isd_grp["#{track}"].first rescue nil
        unless isd.nil?
          if !magento_tracks.include? track.to_s.strip
            item_id = isd.get_item_id
            unless item_id.nil?
              shipment_id = @magento.call("order_shipment.create", order.orderid.to_s, { item_id => isd.qty_shipped }, comment, send_email, include_comment)
              unless shipment_id.nil?
                track_id = @magento.call("order_shipment.addTrack", shipment_id, "ups", "", track)
                MagentoShipment.create(:shipment_id => shipment_id, :order_id => isd.order_id, :track_id => track_id)
              end
            else
              RedMailer.delay(:queue => "emails").notifier("Error: IscShipmentData.get_item_id - #{isd.inspect} ")
            end
          end
        end
      end
    rescue Exception => e
      RedMailer.delay(:queue => "emails").notifier("Error: Mage.create_shipment(#{order_id}, #{site_id}) - #{e.message}")
    end
  end

  def self.insert_order(order_details)
    order_info     = order_details[:order]
    customer_info  = order_details[:customer]
    order_products = order_details[:order_products]
    order_address  = order_details[:order_address]
    
    site = Site.find_by_sitecode(Constant::PKY_CODE)
    IscOrder.reconfigure_db(site.id)
    
    dup = IscOrder.where("mage_order_id = ?", order_info[:mage_order_id])

    if dup.empty?
      order = IscOrder.new(order_info)
      order.orderid = order_info[:orderid]

      if order.save
        customer = IscCustomer.new(customer_info)
        customer.save
        order.update_attribute(:ordcustid, customer.id)

        order_products.each do |prod_info|
          prod = IscOrderProduct.new(prod_info)
          prod.orderorderid = order.orderid
          prod.save 
        end
        
        address = IscOrderAddress.new(order_address)
        address.order_id = order.orderid
        address.save
        
      end
    end    
       
  end
  
  def self.get_value(key, array = {})
    return "" if array.empty? || key.to_s.blank?
    
    array.each do |hash|
      if hash[:key].to_s == key
        if hash[:value].class == Hash || hash[:value].class == Array
          return hash[:value]
        else
          return hash[:value].to_s
        end
      end
    end
    
    ""
  end

  
  def self.get_product(magento, product_id)
    product_h = nil
    begin
      product_h = @magento.call("catalog_product.info", product_id) 
    rescue Exception => e
      RedMailer.delay(:queue => "emails").notifier("Error: Mage.get_product(.., #{product_id}) - #{e.message}")
    end
    return product_h
  end
  
  #def self.get_product_list(magento)
  def self.get_product_list
    product_list = nil
    begin
      product_list = @magento.call("catalog_product.list")
    rescue Exception => e
      RedMailer.delay(:queue => "emails").notifier("Error: Mage.get_product_list: #{e.message}")
    end
    # Output is array of E.g. {"product_id"=>"765", "sku"=>"XSGATONR25C15", "name"=>"アトピカ25mg", "set"=>"313", "type"=>"simple", "category_ids"=>["76", "86", "88", "124", "137"], "website_ids"=>["2"]}
    return product_list
  end
  
  def self.create_update_iscorder(mg_order, site_id)
    #order - order hash from magento api
    Rails.logger.info("\n\n\n\n\nmg_order #{mg_order['increment_id']}")
    IscOrder.reconfigure_db(18)
      
    isc_order = IscOrder.find(mg_order['increment_id'].to_i) rescue IscOrder.new
    isc_order.orderid          = mg_order['increment_id']
    isc_order.increment_id     = mg_order['increment_id'].to_i
    isc_order.store_id         = mg_order['store_id'].to_i
    isc_order.mage_order_id    = mg_order['order_id'].to_i
    isc_order.shipping_address = mg_order['shipping_address']
    isc_order.billing_address  = mg_order['billing_address']
    isc_order.order_info       = mg_order

    isc_order.ordbillsuburb = ""
    isc_order.ordtrackingno = ""
    isc_order.ordbillemail = ""
    isc_order.ordbillzip = ""
    isc_order.ordbillphone = ""
    isc_order.ordbillstreet1 = ""
    isc_order.ordbillstreet2 = ""
    isc_order.ordbillstate = ""
    isc_order.orderpaymentmethod = ""
    isc_order.ordbillfirstname = ""
    isc_order.ordbilllastname = ""
    isc_order.ordstatus = Helpers.mage_to_isc_ordstatus(mg_order['status'])
    isc_order.orddate = mg_order['created_at'].to_time.to_i
    isc_order.ordlastmodified = mg_order['updated_at'].to_time.to_i
    
    isc_order.save!
    
    isc_order
  end  

  #def self.update_inventory(magento, product_id_qtys = {})
  def self.update_inventory(product_id_qtys = {})
    product_id_qtys.each do |pid, qty|
      product_id = pid
      stock_item_data = { 'qty' => qty.to_s, 'is_in_stock' => 1, 'manage_stock' => 1 }
      result = false
      
      begin
        result = @magento.call("cataloginventory_stock_item.update", product_id, stock_item_data)
      rescue Exception => e
        RedMailer.delay(:queue => "emails").notifier("Error: Mage.update_inventory(#{product_id_qtys}) --  magento.call('cataloginventory_stock_item.update',  #{product_id}, #{stock_item_data}) - #{e.message}")
      end
      
      return result
    end
  end

  def self.item_rows(items = {})
    return '' if items.empty?

    item_string = "\n 【ご注文商品】  \n"

    items.each do |item|
      next if item['product_type'] == 'bundle'
      item_string += "#{item['name']}  x#{item['qty_ordered'].to_i} \n"
    end

    return item_string
  end
  
end
