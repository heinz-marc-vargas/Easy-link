class OrderProcessing < ActiveRecord::Base
  #has_one :isc_order_product, :foreign_key => "orderprodid"
  belongs_to :isc_order_product, :foreign_key => "orderprodid"
  belongs_to :isc_order, :foreign_key => "order_id"
  belongs_to :site
  belongs_to :supplier
  belongs_to :product
  
  scope :version2, lambda { where("oc_version=2") }
  scope :unsent_orders, version2.where("sent IS NULL AND parent_order_id IS NULL")
  scope :suborders, lambda { |order_id| version2.where("parent_order_id = ? AND parent_order_id IS NOT NULL", order_id) }
  scope :main, version2.where("parent_order_id IS NULL")
  scope :main_unsent, version2.where("sent IS NULL and parent_order_id IS NULL") #same with unsent_orders

  establish_connection Rails.application.config.database_configuration["#{Rails.env}"]
  reset_column_information

  simple_audit do |op_record|
    {
        :id => op_record.id,
        :order_id => op_record.order_id,
        :sent => op_record.sent,
        :created_at => op_record.created_at,
        :updated_at => op_record.updated_at,
        :parent_order_id => op_record.parent_order_id,
        :orderprodid => op_record.orderprodid,
        :product_id => op_record.product_id,
        :qty => op_record.qty,
        :supplier_id => op_record.supplier_id,
        :site_id => op_record.site_id,
        :split_flag => op_record.split_flag,
        :merge_to => op_record.merge_to,
        :combi_id => op_record.combi_id,
        :supplier_ids => op_record.supplier_ids,
        :username_method => User.current
    }
  end
  
  class << self
    
    # ots qty should be equal to ops qty or less than
    # qty should be check agains order_processssings
    def get_possible_duplicates(site_id, date="")
      probable_duplicates = []
      site  = Site.find(site_id)
      IscOrder.reconfigure_db(site_id)
      date = date.blank? ? Time.current.to_date : date.to_date
      otss = OrdersToSupplier.where("(response_status like '%Success%' OR response_status='ok') AND site_id = ? AND DATE_FORMAT(created_at, '%Y-%m-%d')=?", site_id, date.strftime("%Y-%m-%d")).order("created_at DESC")
      ots_by_orderid = otss.group_by(&:order_id)
      order_ids = otss.map(&:order_id)
      order_ids.uniq!

      opss = OrderProcessing.where("order_id IN (?) AND sent=1 AND oc_version=2", order_ids).order("updated_at DESC")
      ops_by_orderid = opss.group_by(&:order_id)

      orders = IscOrder.where("orderid IN (?)", order_ids).includes(:isc_order_products)
      orders = orders.group_by(&:orderid)
    
      ots_by_orderid.keys.each do |order_id|
        #OrdersToSuppliers
        items_hash = {}
        ots_rows   = ots_by_orderid[order_id]
        ots_rows.each do |ots|
          ots.order_string[:order_params]['itemsString'].split(":~:").each do |item_line|
            sku, x, qty = item_line.split("~")
            ots_qty = items_hash["#{sku}"].nil? ? 0 : items_hash["#{sku}"].to_i
            items_hash["#{sku}"] = ots_qty.to_i + qty.to_i
            #items_hash['ZZZ_LUM3ML] = 10
          end
        end
          
        order = orders[order_id].first
        product_hash = {}
        order.isc_order_products.each do |oip|
          sproducts = ShopProduct.where("site_id = ? AND isc_product_id = ?", site.id, oip.ordprodid)
          sproducts.each do |sp|
            if items_hash.keys.include? sp.product.ext_product_id
              sku = sp.product.ext_product_id
              prev_qty = product_hash["#{sku}"].nil? ? 0 : product_hash["#{sku}"].to_i
              product_hash["#{sku}"] = prev_qty + (sp.bundle_qty.to_i * oip.ordprodqty.to_i)
            else
              products = Product.where("uid=?", sp.product.uid)
              products.each do |prod|
                if items_hash.keys.include? prod.ext_product_id
                  sku = prod.ext_product_id
                  prev_qty = product_hash["#{sku}"].nil? ? 0 : product_hash["#{sku}"].to_i
                  product_hash["#{sku}"] = prev_qty + (sp.bundle_qty.to_i * oip.ordprodqty.to_i)
                end
              end
            end
          end
        end
          
        product_hash.each_entry do |product_ordered|
          sku, qty = product_ordered
          if items_hash.key? sku
            if items_hash["#{sku}"].to_i > qty.to_i
              hash = {
                :order_id      => order_id,
                :sku           => sku,
                :submitted_qty => qty,
                :ordered_qty   => items_hash["#{sku}"]
              }
              probable_duplicates << hash
            end
          end
        end
      end

      probable_duplicates
    end
    
    def remove_duplicate(order_ids = [], site_id)
      return if order_ids.empty?
      order_ids.uniq!
      ops = OrderProcessing.where("order_id IN (?) AND sent IS NULL", order_ids)
      byorderid = ops.group_by(&:order_id)
      remove_cache = false
      
      byorderid.keys.each do |order_id|
        line = []
        
        byorderid[order_id].each do |op|
          test_line = "#{op.order_id}-#{op.orderprodid}-#{op.product_id}-#{op.qty}-#{op.supplier_id}-#{op.split_flag}"
          if line.include? test_line
            op.update_attribute(:sent, -1)
            remove_cache = true
          else
            line << test_line
          end
        end
      end

      Rails.cache.delete("views/#{site_id}-preview_supplier_order_data") if remove_cache
    end
    
    def remove_byproduct_id(product_ids = [])
      ops = where("SENT IS NULL AND product_id IN (?)", product_ids)
      ops.delete_all unless ops.empty?
    end
    
    def get_reorder_split_flag(order_id)
      return nil if order_id.nil?
      reorder_split_flag_char = "r" # reorder split flags should be in the format r1, r2, r3, ..., rn
      
      otss = OrdersToSupplier.where("order_id = ?", order_id)
      return nil if otss.empty? # Order has not been sent to supplier(s) before
        
      # just get all the supplier orders with split flag starting with 'r', but isn't r
      otss = OrdersToSupplier.where("split_flag IS NOT NULL AND split_flag != '' AND order_id = ? AND split_flag LIKE ? AND split_flag != 'r'", order_id, "r%" ).order("split_flag DESC")

      n = 0
      if (otss != []) # if reorder(s) have been made before
        otss.each do |ots|  # loop through the supplier orders with split flag starting with 'r', to find the max number n for the rn's present
          sfn = ots.split_flag.split("r").last
          if sfn.to_i > 0
            n = sfn.to_i
          end
        end
      end

      return (reorder_split_flag_char + (n + 1).to_s)
    end
    
    def send_shipment_tracking_notification(site_id, oids = [], filename=nil)
      begin
        raise "ERROR: OrderProcessing.send_shipment_tracking_notification - Site ID not specifid." if site_id.nil?
        raise "ERROR: OrderProcessing.send_shipment_tracking_notification - Order IDs not specifid." if oids.empty?
        Delayed::Worker.logger.info("#{oids}")

        IscOrder.reconfigure_db(site_id)
        orders = IscOrder.where("orderid IN (?)", oids)
        isd = IscShipmentData.find_by_file_name(filename)

        orders.each do |order|
          Delayed::Worker.logger.info("#{order.inspect}")
          mn ||= MailNotification.create_log({ :order_id => order.orderid, :site_id => site_id, :email => order.isc_customer.custconemail, :mailable => isd, :filename => filename }) 
          Delayed::Worker.logger.info("MailNotification: #{mn}")

          begin
            Delayed::Worker.logger.info("Sending email now...")
            IscOrder.status_update_email(order, site_id)
            mn.update_attribute(:sent, true)
          rescue Exception => e
            mn.update_attribute(:log, e.message.to_s) unless mn.nil?
            Delayed::Worker.logger.info("Error: While trying to send status change notification to: " + order.isc_customer.custconemail + ", Exception: " + e.message.inspect)
          end
        end
      rescue Exception => e
        Delayed::Worker.logger.info("SEND_SHIPMENT_TRACKING_NOTIFICATION_ERROR: #{e.message.to_s}")
      end
    end    

    
    def notsent_orders(date, site_id, only_oc2 = true)
      if only_oc2
        version2.where("merge_to IS NULL AND sent = 0 AND site_id = ? AND DATE_FORMAT(created_at, '%Y-%m-%d') = ?", site_id, date).group("order_id")
      else
        where("merge_to IS NULL AND sent = 0 AND site_id = ? AND DATE_FORMAT(created_at, '%Y-%m-%d') = ?", site_id, date).group("order_id")
      end
    end
    
    #class method
    def get_suppliers(ordproc, site_id)
      suppliers = []
      sproduct = ShopProduct.where("isc_product_id = ? AND site_id = ?", ordproc.isc_order_product.ordprodid.to_i, site_id.to_i).first
      return [] if sproduct.nil?

      if sproduct.product.uid.to_i > 0
        products = Product.where("uid = ?", sproduct.product.uid.to_i)
        suppliers += Supplier.where("id IN (?)", products.map(&:supplier_id))
      else
        suppliers << sproduct.product.supplier unless sproduct.product.nil?
      end

      return suppliers.uniq
    end

    def send_to_queue(order_processings = [], site_id = nil, test_mode = false)
       raise "Please set site_id" if site_id.nil?

       add_to_delayedjob(order_processings, site_id, test_mode)
    end
    
    def add_to_delayedjob(order_procs, site_id, test_mode)
      return nil if site_id.nil? || order_procs.nil?
      order_proc_ids = order_procs.map(&:id).join(",")

      Rails.logger.info("::::::::::::::::::::::::#{site_id}::::::::::::::::::::::::::::::::::::::::::::::::::")
      Rails.logger.info("proc ids: #{order_proc_ids.inspect}")

      OrderSender.delay(:queue => Constant::ORDER_QUEUE).prepare_order(order_proc_ids, site_id, test_mode)
    end

    def createsplit(params)
      orderproc = OrderProcessing.find_by_order_id_and_site_id(params[:order_id], params[:site_id]) || OrderProcessing.new(params)
      orderproc.oc_version = 2
      orderproc.save!
      orderproc
    end
    
    def create_order_processing(order_id, site_id)
      return nil if order_id.nil? || site_id.nil?

      result = { :created_op => [], :missing_lines => [] }
            
      IscOrder.reconfigure_db(site_id)
      order = IscOrder.find(order_id)
      
      orderprodids = order.isc_order_products.map(&:orderprodid) rescue []
      OrderProcessing.where("orderprodid NOT IN (?) AND order_id = ?", orderprodids, order.orderid).delete_all unless orderprodids.empty?
      
      order.isc_order_products.each do |order_prod|
        sp = ShopProduct.where("isc_product_id = ? AND site_id = ?", order_prod.ordprodid, site_id)
        
        unless sp.empty?
          product_suppliers = []
          sp.each do |sproduct|
            
            if sproduct.product.uid.to_i > 0
              products = Product.where("uid = ?", sproduct.product.uid.to_i)
              product_suppliers << Supplier.where("id IN (?)", products.map(&:supplier_id)).map(&:id)
            else
              product_suppliers << [sproduct.product.supplier.id] unless sproduct.product.nil?
            end
          end

          init_supp_ids = product_suppliers.first
          product_suppliers.each do |arr|
            init_supp_ids = init_supp_ids & arr
          end

          init_supp_ids = [sp.first.supplier_id] if init_supp_ids.empty?
          
          combi_id = nil
          sp.each do |sproduct|
            total_qty = (order_prod.ordprodqty.to_i * sproduct.bundle_qty.to_i) rescue 0
            dup_orderproc = OrderProcessing.where("oc_version=2 AND sent IS NULL AND order_id = ? AND orderprodid = ? AND product_id = ? AND site_id = ?", order.orderid, order_prod.orderprodid, sproduct.product_id, IscOrder.site_id)
            dup_orderproc += OrderProcessing.where("oc_version=2 AND sent=0 AND order_id = ? AND orderprodid = ? AND product_id = ? AND site_id = ?", order.orderid, order_prod.orderprodid, sproduct.product_id, IscOrder.site_id)
            dup_sent_orderproc = OrderProcessing.where("oc_version=2 AND sent=1 AND order_id = ? AND orderprodid = ? AND product_id = ? AND site_id = ?", order.orderid, order_prod.orderprodid, sproduct.product_id, IscOrder.site_id)
              
            if dup_orderproc.empty? && dup_sent_orderproc.empty?
              orderproc =  OrderProcessing.new
              orderproc.order_id = order.orderid
              orderproc.orderprodid  = order_prod.orderprodid
              orderproc.product_id = sproduct.product_id rescue nil
              orderproc.qty = total_qty
              orderproc.supplier_ids =  init_supp_ids.uniq.join(",")
              orderproc.split_by_val = nil
              orderproc.site_id =  IscOrder.site_id rescue nil
              orderproc.oc_version = 2
              orderproc.combi_id = combi_id
              orderproc.supplier_id =  sproduct.supplier_id.to_i
              orderproc.save!
              
              combi_id = sp.length > 1 ? orderproc.id: nil
              
              result[:created_op] << order_prod
              Rails.cache.delete("views/#{IscOrder.site_id}-preview_supplier_order_data")
            end
          end
        else
          result[:missing_lines] << order_prod
        end
      end
      
      result
    end
    
    def createnew_per_orderline(orders = [], site_id)
      result = {
        :created_lines => [],
        :missing_lines => []
      }
     
      for page in 1..orders.total_pages
        IscOrder.reconfigure_db(site_id)
        orders.page(page).each do |order|
          
          
          orderprodids = order.isc_order_products.map(&:orderprodid) rescue []
          OrderProcessing.where("orderprodid NOT IN (?) AND order_id = ?", orderprodids, order.orderid).delete_all unless orderprodids.empty?
          
          order.isc_order_products.each do |order_prod|
            sp = ShopProduct.where("isc_product_id = ? AND site_id = ?", order_prod.ordprodid, IscOrder.site_id)

            unless sp.empty?
                product_suppliers = []
                sp.each do |sproduct|
                  if sproduct.product.uid.to_i > 0
                    products = Product.where("uid = ?", sproduct.product.uid.to_i)
                    product_suppliers << Supplier.where("id IN (?)", products.map(&:supplier_id)).map(&:id)
                  else
                    product_suppliers << [sproduct.product.supplier.id] unless sproduct.product.nil?
                  end
                end

                init_supp_ids = product_suppliers.first
                product_suppliers.each do |arr|
                  init_supp_ids = init_supp_ids & arr
                end

                init_supp_ids = [sp.first.supplier_id] if init_supp_ids.empty?
              
              combi_id = nil
              sp.each do |sproduct|
                #init_supp_ids << sproduct.default_supplier_id unless sproduct.default_supplier_id.nil?
                
                total_qty = (order_prod.ordprodqty.to_i * sproduct.bundle_qty.to_i) rescue 0
                dup_orderproc = OrderProcessing.where("oc_version=2 AND sent IS NULL AND order_id = ? AND orderprodid = ? AND product_id = ? AND site_id = ?", order.orderid, order_prod.orderprodid, sproduct.product_id, IscOrder.site_id)
                dup_orderproc += OrderProcessing.where("oc_version=2 AND sent=0 AND order_id = ? AND orderprodid = ? AND product_id = ? AND site_id = ?", order.orderid, order_prod.orderprodid, sproduct.product_id, IscOrder.site_id)
                dup_sent_orderproc = OrderProcessing.where("oc_version=2 AND sent=1 AND order_id = ? AND orderprodid = ? AND product_id = ? AND site_id = ?", order.orderid, order_prod.orderprodid, sproduct.product_id, IscOrder.site_id)
                  
                if dup_orderproc.empty? && dup_sent_orderproc.empty?
                  orderproc =  OrderProcessing.new
                  orderproc.order_id = order.orderid
                  orderproc.orderprodid  = order_prod.orderprodid
                  orderproc.product_id = sproduct.product_id rescue nil
                  orderproc.qty = total_qty
                  orderproc.supplier_ids =  init_supp_ids.uniq.join(",")
                  orderproc.split_by_val = nil
                  orderproc.site_id =  IscOrder.site_id rescue nil
                  orderproc.oc_version = 2
                  orderproc.combi_id = combi_id

                  orderproc.supplier_id =  sproduct.supplier_id.to_i
                  orderproc.save!
                  
                  combi_id = sp.length > 1 ? orderproc.id: nil
                  
                  result[:created_lines] << order_prod
                  Rails.cache.delete("views/#{IscOrder.site_id}-preview_supplier_order_data")
                else
                  #just update the supplier_id
                  #dup_orderproc.each do |op_rec|
                  #  RedMailer.delay(:queue => "emails").notifier("Notice: Updating OrderProcessing #{op_rec.inspect} -- product_id=#{sproduct.product_id}; supplier_id=#{sproduct.supplier_id}")
                  #  op_rec.update_attribute(:supplier_id, sproduct.supplier_id.to_i)
                  #  op_rec.update_attribute(:product_id, sproduct.product_id)
                  #end
                end
              end
            else
              result[:missing_lines] << order_prod
            end
          end
          
          
          
          
        end
      end
      
      return result
    end
      
  end
  # end of class methods

  def change_supplier(supp_id=nil)
    return if supp_id.nil?
    self.update_attribute(:supplier_id, supp_id)

    #if having combis
    combis = OrderProcessing.where("combi_id = ?", self.id)
    unless combis.empty?
      combis.each{|op| op.update_attribute(:supplier_id, supp_id) }
    end
      
    #if having splits
    splitted = OrderProcessing.where("parent_order_id = ?", self.order_id)
    unless splitted.empty?
      splitted.each{|op| op.update_attribute(:supplier_id, supp_id) }
    end
  end
  
  def split_order(by_qty, site_id)
    new_orders = []
    return [] if by_qty.nil?
    return [] if by_qty.blank? || (by_qty.to_i < Constant::MIN_SPLIT_QUANTITY)
    return [] if self.qty.to_i < Constant::MIN_SPLIT_QUANTITY
    letter = Constant::STARTING_SPLIT_LETTER
    
    suborders = OrderProcessing.suborders(self.order_id)
    suborders.delete_all unless suborders.empty?
    leftqty = self.qty.to_i - by_qty.to_i
    number_of_split = (leftqty.to_f / by_qty.to_f).ceil

    for i in 1..number_of_split
       # creating duplicate here
       copy = self.clone
       copy.order_id = copy.order_id
       copy.split_flag = letter
       copy.parent_order_id = self.order_id

       new_qty = (leftqty.to_i - by_qty.to_i) > 0 ? by_qty.to_i : leftqty
              
       leftqty = leftqty - new_qty
       copy.qty = new_qty

       copy.supplier_id = self.supplier_id
       
       if copy.save!
         new_orders << copy
       end
       letter.next!       
    end
    
    self.qty = by_qty.to_i
    self.split_by_val = by_qty.to_i
    self.oc_version = 2
    self.save
    
    new_orders
  end
  
  def suborders
    OrderProcessing.suborders(self.order_id)
  end
  
  def parent_and_suborders
    OrderProcessing.where("oc_version=2 AND order_id = ? AND site_id = ?", self.order_id, self.site_id)
  end

  #instance method
  def get_suppliers(siteid)

    suppliers = []    
    begin
      if siteid.to_i == 18
        sproduct = ShopProduct.where("isc_product_id = ? AND site_id = ?", self.isc_product_id, siteid.to_i).first
        return [] if sproduct.nil?
      
        return [sproduct.product.supplier] if sproduct.nil?
  
        if sproduct.product.uid.to_i > 0
          products = Product.where("uid = ?", sproduct.product.uid.to_i)
          suppliers += Supplier.where("id IN (?)", products.map(&:supplier_id))
        else
          suppliers << sproduct.product.supplier unless sproduct.product.nil?
        end
        
      else
      
        IscOrder.reconfigure_db(siteid)
        iop = IscOrderProduct.find(self.orderprodid)
        sproduct = ShopProduct.where("isc_product_id = ? AND site_id = ?", iop.ordprodid.to_i, siteid.to_i).first
        return [] if sproduct.nil?
      
        return [sproduct.product.supplier] if sproduct.nil?
  
        if sproduct.product.uid.to_i > 0
          products = Product.where("uid = ?", sproduct.product.uid.to_i)
          suppliers += Supplier.where("id IN (?)", products.map(&:supplier_id))
        else
          suppliers << sproduct.product.supplier unless sproduct.product.nil?
        end
      end
      
      return suppliers.uniq
    rescue Exception => e
      RedMailer.delay(:queue => "emails").notifier("Error: OrderProcessing.get_suppliers(#{siteid}) - IscOrderProduct.orderprodid does not exist. #{self.inspect}")
      return []
    end
  end
  
  
  def splitted?
    self.split_by_val.to_i > 0
  end

  # { :site_id => 1 }
  #def product(options={})
  #  product = Product.find(self.product_id.to_i) rescue nil
  #  return product
    
    #iop = IscOrderProduct.find(self.orderprodid.to_i)
    #sp = ShopProduct.where("isc_product_id=? AND site_id = ?", iop.ordprodid, self.site_id).first
    
    #if self.supplier_id.to_i != sp.supplier_id.to_i
    #  prod = Product.where("uid=? and supplier_id = ? and uid != 0", sp.product.uid, self.supplier_id).first rescue nil
    #else
    #  prod = Product.find(sp.product_id) rescue nil
    #end

    #return prod unless prod.nil?
    #return nil if prod.nil?
    #return sp.first.product
  #end
  
  def all_orders_submitted?
    if self.site_id != 18
      order = IscOrder.find(self.order_id)
      orders = OrdersToSupplier.select("product_ids, response_status").where("order_id = ?", self.order_id)           
      order_product_ids_arr = order.ordered_products                                                                             
      order_product_ids = ""                                                                                                             
      order_prod_ids_arr = []
      order_prod_ids = ""
          
      if (orders == [])                                                                                                                  
        return false                                                                                                                     
      end                                                                                                                                
      
      # get array of orderprodids of products ordered successfully                                                                       
      orders.each do |o|
        if ((o.response_status.include? "ok") || (o.response_status.include? "Success"))                                                 
          order_prod_ids += (o.product_ids + ",")                                                                                        
        end
      end   
      
      if (order_prod_ids == "")                                                                                                          
        return false
      end
  
      order_prod_ids[order_prod_ids.length - 1] = ""                                                                                     
      order_prod_ids_arr = order_prod_ids.split(",")                                                                                     
  
      # compare with array of orderprodids of products in order                                                                          
      order_product_ids_arr.each do |opi|
        if ((order_prod_ids_arr.index opi) == nil)
          return false
        end
      end
  
      return true 
    
    else
      #magento orders
      
      items_id = []
      self.isc_order.order_info['items'].each do |item|
        next if item['product_type'] == 'bundle'
        items_id << item['item_id']
      end

      ots = OrdersToSupplier.select("product_ids, response_status").where("order_id = ?", self.order_id)
      order_product_ids = ""                                                                                                             
      order_prod_ids_arr = []

      item_ids = ""

      if (ots == [])                                                                                                                  
        return false                                                                                                                     
      end                                                                                                                                
  
      ots.each do |o|
        if ((o.response_status.include? "ok") || (o.response_status.include? "Success"))                                                 
          item_ids += (o.product_ids + ",")
        end
      end   
      
      if (item_ids == "")                                                                                                          
        return false
      end
  
      item_ids.chop!                                                                                     
      order_prod_ids_arr = item_ids.split(",")                                                                                     
  
      items_id.each do |item_id|
        if ((order_prod_ids_arr.index item_id) == nil)
          return false
        end
      end
  
      return true 
      
    end
    
  end
  
  def mark_as_sent
    self.update_attribute(:sent, 1)    
  end   

  def from_magento?
    (self.site_id == 18)
  end  
end
