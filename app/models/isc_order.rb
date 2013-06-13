#encoding: utf-8
class IscOrder < ActiveRecord::Base
  require 'rest-client'
  require 'csv'

  set_primary_key "orderid"
  
  belongs_to :isc_order_status, :foreign_key => "ordstatus"
  belongs_to :isc_customer, :foreign_key => "ordcustid"
  belongs_to :medex_order, :foreign_key => "order_id"
  belongs_to :order_processing, :foreign_key => "order_id"
  belongs_to :orders_to_supplier, :foreign_key => "order_id"
    
  has_many :isc_order_products, :foreign_key => "orderorderid", :dependent => :destroy
  has_one  :isc_order_shipping, :foreign_key => "order_id", :dependent => :destroy
  has_one  :isc_order_address, :foreign_key => "order_id", :dependent => :destroy
  has_many :isc_shipments, :foreign_key => "shiporderid", :dependent => :destroy
  has_many :isc_shipment_datas, :foreign_key => "order_id", :dependent => :destroy
  has_one  :isc_transaction, :foreign_key => "orderid", :dependent => :destroy
  has_one  :isc_countries, :foreign_key => "countryid", :dependent => :destroy
  has_one  :isc_country_state, :foreign_key => "stateid", :dependent => :destroy
  has_many :order_processings, :foreign_key => "order_id", :dependent => :destroy
  has_many :magento_shipments, :foreign_key => "order_id", :dependent => :destroy
  
  serialize :shipping_address
  serialize :billing_address
  serialize :order_info

  self.per_page = Constant::PERPAGE
  STATUS = {
              "Deleted" => ["0"],
              "Pending" => ["1"],
               "Unpaid" => ["7","8"],
                 "Paid" => ["11"],
            "Submitted" => ["9"],
    "Partially Shipped" => ["3"],
              "Shipped" => ["2","10"],
            "Cancelled" => ["4","5","6"],
                  "All" => ["1","2","3","4","5","6","7","8","9","10","11","12","13","14","15"]
  }
  
       PAID = "Paid"
     UNPAID = "Unpaid"
  SUBMITTED = "Submitted"
    SHIPPED = "Shipped"

  MAGE_STATUS = {
              "canceled" => "Cancelled",
               "pending" => "Pending",
       "pending_payment" => "Unpaid",
            "processing" => "Paid",
             "submitted" => "Submitted",
     "partially_shipped" => "Partially Shipped",
              "complete" => "Shipped",
  }

  before_save do |order|
    order.ordlastmodified = Time.current.to_i
  end

  scope :paid, where("ordstatus IN (?) AND deleted=0", STATUS['Paid'])
  scope :submitted, where("ordstatus IN (?) AND deleted=0", STATUS['Submitted'])
  scope :shipped, where("ordstatus IN (?) AND deleted=0", STATUS['Shipped'])
  
  simple_audit do |ord_record|
    {
        :orderid => ord_record.orderid,
        :ordstatus => ord_record.ordstatus,
        :ordtrackingno => ord_record.ordtrackingno,
        :orddateshipped => ord_record.orddateshipped,
        :ordnotes => ord_record.ordnotes,
        :ordcustmessage => ord_record.ordcustmessage,
        :ordbillstreet1 => ord_record.ordbillstreet1,
        :ordbillstreet2 => ord_record.ordbillstreet2,
        :ordbillsuburb => ord_record.ordbillsuburb,
        :ordbillstate => ord_record.ordbillstate,
        :ordbillstateid => ord_record.ordbillstateid,
        :ordbillzip => ord_record.ordbillzip,
        :ordbillcountry => ord_record.ordbillcountry,
        :ordbillcountryid => ord_record.ordbillcountryid,
        :ordbillcountrycode => ord_record.ordbillcountrycode,
        :ordbillphone => ord_record.ordbillphone,
        :site_id => (Site.current_site.id rescue nil),
        :username_method => User.current,
        :orddate => ord_record.orddate
    }
  end

  class << self

    def set_webshark_status(order_id, site_id, status_id = "0")
      Rails.logger.info("Setting status to YHVH site...")
      Delayed::Worker.logger.info("Setting status to YHVH site...")
      return nil if order_id.nil? || site_id.nil?
      return nil if site_id.to_i != Constant::WEBSHARK_SITE_ID
      IscOrder.reconfigure_db(site_id)
      
      begin
        cookies = {:cookies => {
          :CK_AUTH_CID => CONFIG[:ck_auth_cid],
          :CK_AUTH_NAME => CONFIG[:ck_auth_name],
          :CK_AUTH_USER => CONFIG[:webshark_id],
          :CK_AUTH_PW => CONFIG[:webshark_pwd],
          :__utma => CONFIG[:utma],
          :__utmz => CONFIG[:utmz],
          :__utmb => CONFIG[:utmb],
          :__utmc => CONFIG[:utmc]}}
        
        order = IscOrder.find(order_id)
        return nil if order.nil?
        possible_tids = order.ordnotes.gsub(/^(WS Transaction ID: _)\d{7,7}/)
        tid = possible_tids.first.to_s.split("_").last.to_s rescue nil
        return nil if tid.nil?
        ord_date = Time.at(order.orddate).to_date

        options = { "s_status0" =>"", "s_status1"=>"", "s_status2"=>"", "s_status4"=>"", 
                  "s_status5" =>"", "s_status97"=>"", "s_status98"=>"", "s_word"=>"", 
                  "s_type"=>"", "s_payment"=>"", "s_sy"=> ord_date.year.to_s, "s_sm"=> ord_date.month.to_s, "s_sd"=> ord_date.day.to_s, 
                  "s_ey"=> ord_date.year.to_s, "s_em"=> ord_date.month.to_s, "s_ed"=> ord_date.day.to_s, "p_num"=>"1", "p_bulk"=> status_id, 
                  "tr_color"=>"tr#{tid}", 
                  "order_status_code" => { "#{tid}"=> status_id },
                  "statement" => {"#{tid}"=> status_id },
                  "p_num2" => "1", "act"=> "update_all"
                  }
  
        logger.info("get_ws_otids OPTIONS: " + options.inspect )
        logger.info("get_ws_otids URL: " + CONFIG[:webshark_status_url].to_s )

        response = RestClient.post(CONFIG[:webshark_status_url], options, cookies)
        if response.to_s.include?("han_login_midashi")
          RedMailer.delay(:queue => "others").notifier("Error: Unable to set the order status in YHVH site. #{order_id} - #{site_id} -- #{response.to_s}")
        end
        return response
      rescue Exception => e
        Rails.logger.info("ERROR: #{e.message}")
        msg = "ERROR: IscOrder.set_webshark_status(#{order.orderid}, #{site_id}, #{status_id})"
        msg += "\n transaction id: #{tid} \n"
        msg += e.message.to_s
        RedMailer.delay(:queue => "others").notifier(msg)
      end
      
      nil      
    end
        
    def status_update_email(order, site_id)
      Rails.logger.info("STATUS_UPDATE_EMAIL: #{order.orderid} : #{site_id}")
      site = Site.find(site_id) rescue nil
      return nil if site.nil? || order.nil?
      order_id = order.orderid
      site_id = 17 if order.orderid.to_s.first == "9"
      IscOrder.reconfigure_db(site_id)
      order = IscOrder.find(order_id)
      return nil if ![7, 8, 11, 9, 3, 2, 10].include?(order.ordstatus.to_i)
      
      mail_token = Time.current.to_i.to_s
      mail_option = { :token => mail_token }

      case site.sitecode.to_s
      when "PK"
        OrderMailer.delay(:queue => "emails").pk_order_status_change_email(order.orderid, site_id, mail_option)
        notes = { :order_id => order.orderid, :site_id => site_id, :status => order.ordstatus }
        MailNotification.create_log({ :order_id => order.orderid, :site_id => site_id, :email => (order.isc_customer.custconemail.to_s rescue ''), :mailable => order, :token => mail_token, :notes => notes })
      when "GP"
        OrderMailer.delay(:queue => "emails").gp_order_status_change_email(order.orderid, site_id, mail_option)
        notes = { :order_id => order.orderid, :site_id => site_id, :status => order.ordstatus }
        MailNotification.create_log({ :order_id => order.orderid, :site_id => site_id, :email => (order.isc_customer.custconemail.to_s rescue ''), :mailable => order, :token => mail_token, :notes => notes }) 
      when "HB"
        OrderMailer.delay(:queue => "emails").hb_order_status_change_email(order.orderid, site_id, mail_option)
        notes = { :order_id => order.orderid, :site_id => site_id, :status => order.ordstatus }
        MailNotification.create_log({ :order_id => order.orderid, :site_id => site_id, :email => (order.isc_customer.custconemail.to_s rescue ''), :mailable => order, :token => mail_token, :notes => notes }) 
      when "KX"
        OrderMailer.delay(:queue => "emails").kx_order_status_change_email(order.orderid, site_id, mail_option)
        notes = { :order_id => order.orderid, :site_id => site_id, :status => order.ordstatus }
        MailNotification.create_log({ :order_id => order.orderid, :site_id => site_id, :email => (order.isc_customer.custconemail.to_s rescue ''), :mailable => order, :token => mail_token, :notes => notes })
      when "BK"
        OrderMailer.delay(:queue => "emails").bk_order_status_change_email(order.orderid, site_id, mail_option)
        notes = { :order_id => order.orderid, :site_id => site_id, :status => order.ordstatus }
        MailNotification.create_log({ :order_id => order.orderid, :site_id => site_id, :email => (order.isc_customer.custconemail.to_s rescue ''), :mailable => order, :token => mail_token, :notes => notes }) 
      when "WSH"
        OrderMailer.delay(:queue => "emails").ws_order_status_change_email(order.orderid, site_id, mail_option)
        notes = { :order_id => order.orderid, :site_id => site_id, :status => order.ordstatus }
        MailNotification.create_log({ :order_id => order.orderid, :site_id => site_id, :email => (order.isc_customer.custconemail.to_s rescue ''), :mailable => order, :token => mail_token, :notes => notes })
        IscOrder.delay(:queue => "others").set_webshark_status(order.orderid, site_id, Constant::WS_CONFIRM_ID) if order.ordstatus == 2
      when "PKY"
        Mage.delay(:queue => "others").send_email(order.orderid, site_id)
      else
        Rails.logger.info("***** SITE NOT SUPPORTED: #{site.sitecode}")
        return nil
      end
    end

    def order_totals
      results = {}
      order_status = [2, 3, 9, 10, 11]

      orders = select("ordstatus").where("ordstatus IN (?) AND deleted=0 AND orddate BETWEEN ? AND ?", order_status, 7.days.ago.to_i, Time.current.to_i)
      orders_group = orders.group_by(&:ordstatus)
      
      results[:paid] = select("ordstatus").where("ordstatus=11 AND deleted=0 AND orddate BETWEEN ? AND ?", Time.current.beginning_of_day.to_i, Time.current.end_of_day.to_i).length
      results[:submitted] = OrdersToSupplier.submitted_today.count
      results[:shipped] = IscShipmentData.shipped_today.count

      results
    end
    
    def site_id=(site_id)
      @site_id = site_id
    end
    def site_id
      @site_id
    end

    def dbname=(dbname)
      @dbname= dbname
    end
    def dbname
      "#{@dbname}"
    end
    
    def not_queued_paid_orders(site_id=nil)
      return [] if site_id.nil?
      IscOrder.reconfigure_db(site_id)

      paid_orders = IscOrder.paid.includes(:isc_order_address, :isc_order_products)
      paid_orders = paid_orders.where("deleted=0").order("orderid DESC")
      paid_orders
    end
    
    def reconfigure_db(site_id)
      raise "Cannot establish connection. Site ID missing." if site_id.nil?
      isc_site = Site.find(site_id)
      return nil if isc_site.nil?
      
      if Rails.env != "production"
        Rails.logger.info("\n:::::::::::::::::::>> Trying to establish db connection... site_id: #{site_id} #{Rails.env} \n\n")        
        IscOrder.establish_connection "#{Rails.env}_#{isc_site.sitecode}"
        IscOrder.reset_column_information
        IscCustomer.establish_connection "#{Rails.env}_#{isc_site.sitecode}"
        IscCustomer.reset_column_information
        IscOrderAddress.establish_connection "#{Rails.env}_#{isc_site.sitecode}"
        IscOrderAddress.reset_column_information
        IscOrderStatus.establish_connection "#{Rails.env}_#{isc_site.sitecode}"
        IscOrderStatus.reset_column_information
        IscOrderProduct.establish_connection "#{Rails.env}_#{isc_site.sitecode}"
        IscOrderProduct.reset_column_information
        IscProduct.establish_connection "#{Rails.env}_#{isc_site.sitecode}"
        IscProduct.reset_column_information
        IscOrderShipping.establish_connection "#{Rails.env}_#{isc_site.sitecode}"
        IscOrderShipping.reset_column_information
        IscCountryState.establish_connection "#{Rails.env}_#{isc_site.sitecode}"
        IscCountryState.reset_column_information
        IscShipment.establish_connection "#{Rails.env}_#{isc_site.sitecode}"
        IscShipment.reset_column_information
        IscShipmentItem.establish_connection "#{Rails.env}_#{isc_site.sitecode}"
        IscShipmentItem.reset_column_information
        SmGcTransaction.establish_connection "#{Rails.env}_#{isc_site.sitecode}"
        SmGcTransaction.reset_column_information
        IscCustomerCredits.establish_connection "#{Rails.env}_#{isc_site.sitecode}"
        IscCustomerCredits.reset_column_information
        MagentoShipment.establish_connection "#{Rails.env}_#{isc_site.sitecode}"
        MagentoShipment.reset_column_information
        IscReferral.establish_connection "#{Rails.env}_#{isc_site.sitecode}"
        IscReferral.reset_column_information
      else
        Rails.logger.info("\n:::::::::::::::::::>> Trying to establish db connection... site_id: #{site_id} \n\n")
        #dont establish if its using same connection
        if isc_site.database_config.database == IscOrder.dbname
          Rails.logger.info("\n*** using the same connection")
          return
        end
        
        IscOrder.establish_connection(isc_site.database_config.decrypted_attr)
        IscOrder.reset_column_information
        IscCustomer.establish_connection(isc_site.database_config.decrypted_attr)
        IscCustomer.reset_column_information
        IscOrderAddress.establish_connection(isc_site.database_config.decrypted_attr)
        IscOrderAddress.reset_column_information
        IscOrderStatus.establish_connection(isc_site.database_config.decrypted_attr)
        IscOrderStatus.reset_column_information
        IscOrderProduct.establish_connection(isc_site.database_config.decrypted_attr)
        IscOrderProduct.reset_column_information
        IscProduct.establish_connection(isc_site.database_config.decrypted_attr)
        IscProduct.reset_column_information
        IscOrderShipping.establish_connection(isc_site.database_config.decrypted_attr)
        IscOrderShipping.reset_column_information
        IscCountryState.establish_connection(isc_site.database_config.decrypted_attr)
        IscCountryState.reset_column_information
        IscShipment.establish_connection(isc_site.database_config.decrypted_attr)
        IscShipment.reset_column_information
        IscShipmentItem.establish_connection(isc_site.database_config.decrypted_attr)
        IscShipmentItem.reset_column_information
        SmGcTransaction.establish_connection(isc_site.database_config.decrypted_attr)
        SmGcTransaction.reset_column_information
        IscCustomerCredits.establish_connection(isc_site.database_config.decrypted_attr)
        IscCustomerCredits.reset_column_information
        MagentoShipment.establish_connection(isc_site.database_config.decrypted_attr)
        MagentoShipment.reset_column_information
        IscReferral.establish_connection(isc_site.database_config.decrypted_attr)
        IscReferral.reset_column_information
        IscOrder.dbname = isc_site.database_config.database
      end
    end
    
    def get_orders(options = {})
      page = options[:page].nil? ? 1 : options[:page]
      perpage = options[:per_page].blank? ? Constant::PERPAGE : options[:per_page]
      status_ids = get_status_filter(options)
      ids = []
      unless options[:q].blank?
        ids = options[:q].split(",").uniq.compact
      end

      orders = order("orderid DESC").
                page(page).
                per_page(perpage.to_i).
                includes(:isc_customer, :isc_order_address, :isc_order_status, :isc_order_products)

      if options.has_key?("status") && options[:status].to_s == "Deleted"
        orders = orders.where("deleted = 1")
      else
        orders = orders.where("ordstatus IN (?) AND deleted=0", status_ids)        
      end

      orders = orders.where("orderid IN (?) OR orderid like ? ", ids, "#{options[:q].to_s}%") unless ids.empty?
      orders
    end
    
    def get_status_filter(params = {})
      return STATUS['Pending'] if params.nil? || params.empty?
      return STATUS['Pending'] if params[:status].blank?
      return STATUS["#{params[:status]}"]
    end
    
    def powacom_search(site_id, args = {})
      IscOrder.reconfigure_db(site_id)
      search = args[:q]
      result = includes(:isc_customer).where("isc_orders.orderid = ? OR isc_customers.custconemail = ?", search, search)
      
      result
    end
    
  end
  


  def mark_as_paid(site_id)
    self.update_attribute(:ordstatus, 11)
    IscOrder.status_update_email(self, site_id)
  end
  
  def undelete(status, notes="")
    self.deleted = 0
    self.ordstatus = IscOrder::STATUS["#{status}"].first.to_i
    self.ordnotes = notes
    self.save
  end
  
  def setnotes(notes="")
    self.update_attribute(:ordnotes, notes) unless notes.blank?
  end
    
  def unset_credits
    Rails.logger.info("UNSETTING CREDITS...")
    order = self
    begin
      if order.ordstatus != 2 && order.ordstorecreditassigned == 1
        if order.ordstorecreditearned.to_i > 0 && Time.at(order.ordstorecreditearnedenddate).to_date <= Constant::SC_END_DATE
          unless order.isc_customer.nil?
            Rails.logger.info("OLD CREDIT: #{order.isc_customer.custstorecredit}")
            credit = order.isc_customer.custstorecredit.to_f - order.ordstorecreditearned.to_f
            order.isc_customer.update_attribute(:custstorecredit,  credit.to_i)
            order.update_attribute(:ordstorecreditassigned, 0)
            if (order.orderid.to_s[0] != '9')
              log_customer_credits = IscCustomerCredits.new(:customerid => order.ordcustid, :creditamount => -order.ordstorecreditearned.to_f, :credittype => 'order', :creditdate => Time.current.to_i, :credituserid => 1, :creditreason => ("OC: sc assignment. Order ID: " + order.orderid.to_s))
              log_customer_credits.save!
            end
            Rails.logger.info("NEW CREDIT: #{order.isc_customer.custstorecredit}")
          end
        end    
      end
    rescue Exception => e
      Rails.logger.info("UNSET CREDITS ERROR: #{e.message}")
    end    
  end

  def set_credits
    Rails.logger.info("SETTING CREDITS...")
    order = self
    begin
      if order.ordstatus == 2 && order.ordstorecreditassigned == 0
        if order.ordstorecreditearned.to_i > 0 && Time.at(order.ordstorecreditearnedenddate).to_date <= Constant::SC_END_DATE
          unless order.isc_customer.nil?
            Rails.logger.info("OLD CREDIT: #{order.isc_customer.custstorecredit}")
            credit = order.isc_customer.custstorecredit.to_f + order.ordstorecreditearned.to_f
            order.isc_customer.update_attribute(:custstorecredit,  credit.to_i)
            order.update_attribute(:ordstorecreditassigned, 1)
            if (order.orderid.to_s[0] != '9')
              log_customer_credits = IscCustomerCredits.new(:customerid => order.ordcustid, :creditamount => order.ordstorecreditearned.to_f, :credittype => 'order', :creditdate => Time.current.to_i, :credituserid => 1, :creditreason => ("OC: sc assignment. Order ID: " + order.orderid.to_s))
              log_customer_credits.save!
            end
            Rails.logger.info("NEW CREDIT: #{order.isc_customer.custstorecredit}")
          end
        end    
      end
    rescue Exception => e
      Rails.logger.info("SET CREDITS ERROR: #{e.message}")
    end
  end

  def all_orders_submitted?
    orders = OrdersToSupplier.select("product_ids, response_status").where("order_id = ?", self.orderid)           
    order_product_ids_arr = self.ordered_products                                                                             
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
  end

  def all_ordered?
    site_id = nil
    ordered_product_info = {} # ext_product_ids => qty
    order_id = self.orderid
    
    if order_id.to_s.length <= 8
      case order_id.to_s.first
        when "2"  # BK
          site_id = 9
        when "3"  # PK
          site_id = 10
        when "4"  # GP
          site_id = 11
        when "6" # HB
          site_id = 12
        when "7" # 777
          site_id = 15
        when "8" # KX 
          site_id = 16
        when "9" #WS
          site_id = 17
        else                                                                                                                           
          Rails.logger.info("ERROR: Unknown order_id start digit." + order_id.to_s)                                                                                                                          
      end
    else
      site_id = Site.find_by_sitecode("PKY").id
    end
    
    return false if site_id.nil?
    Rails.logger.info("SITE ID: #{site_id}")
    
    if site_id == 18 #magento
      Rails.logger.info("magento order")

      total_qty = 0
      items_ordered = {}
      self.order_info['items'].each do |item|
        next if item['product_type'] == 'bundle'
        
        item_id = item['item_id'].to_i
        sp = ShopProduct.where("site_id=? AND isc_product_id=?", site_id, item['product_id']).first
        items_ordered["#{item_id}"] = { 'product_id' => sp.product.id }
        items_ordered["#{item_id}"] = { 'isc_product_id' => item['product_id'].to_i }
        total_qty += item['qty_ordered'].to_i * sp.bundle_qty
        items_ordered["#{item_id}"] = { 'total_qty' => total_qty }
      end

      total_ordered_qty = 0
      IscShipmentData.where("order_id=?", orderid).group("tracking_num").each do |isd|
        total_ordered_qty += isd.qty_shipped.to_i
      end

      if total_qty == total_ordered_qty
        return true
      else
        return false
      end
     
    else
      IscOrder.reconfigure_db(site_id)
  
      ordered_products = IscOrderProduct.find(:all, :select => "ordprodid, ordprodqty", :conditions => { :orderorderid => order_id }) # Get all ordered products
      return false if ordered_products.empty?
      ordered_shop_products = ShopProduct.find_by_sql("SELECT * FROM shop_products sp, products p WHERE isc_product_id IN 
        (" + ordered_products.collect { |op| op.ordprodid }.join(",") + ") AND site_id = " + site_id.to_s + " AND sp.product_id = p.id")
      return false if ordered_shop_products.empty?
  
      ordered_products.each do |op|
        ordered_supplier_product_ext_pids = []     
        ordered_shop_product = ordered_shop_products.select { |sp| sp.isc_product_id == op.ordprodid }[0]
        Rails.logger.info("ordeed_shop_product #{ordered_shop_product.inspect}")
        return false if ordered_shop_product.nil?  
                                                                                                                                                                                    
        if (ordered_shop_product.uid != 0)                                                                                                         
          ordered_supplier_product = Product.find(:all, :conditions => {:uid => ordered_shop_product.uid})                         
        else
          ordered_supplier_product = [ordered_shop_product]                                                                        
        end
          
        ordered_supplier_product.each do |osp|                                                                                     
          ordered_supplier_product_ext_pids << osp.ext_product_id                                                                  
        end
  
        if (ordered_product_info[ordered_supplier_product_ext_pids.join(",")] == nil)                                              
          ordered_product_info[ordered_supplier_product_ext_pids.join(",")] = op.ordprodqty * ordered_shop_product.bundle_qty      
        else
          ordered_product_info[ordered_supplier_product_ext_pids.join(",")] += op.ordprodqty * ordered_shop_product.bundle_qty     
        end                                                                                                                        
      end
       
    end
    
    Rails.logger.info("ordered_product_info #{ordered_product_info.inspect}")
    ordered_product_info.each do |(key, value)|
      Rails.logger.info("#{key} :: #{value}")
      qty_shipped = 0
      shipped_products = IscShipmentData.find_by_sql("SELECT * FROM isc_shipment_data WHERE order_id = " + order_id.to_s + " AND ext_product_id IN ('" + key.gsub(/-/, "_").split(",").join("','") + "')")

      Rails.logger.info("shipped_products: #{shipped_products}")
      shipped_products.each do |sp|
        qty_shipped += sp.qty_shipped
      end
      Rails.logger.info("#{qty_shipped} < #{value}")
      return false if qty_shipped < value
    end

    return true
  end

  def order_date
    Time.at(orddate).to_formatted_s(:long) rescue "N/A"
  end
  
  def order_date_jp
    Time.at(orddate).strftime("%Y年%m月%d日") rescue "N/A"
  end
  
  def statusdesc
    IscOrderStatus.find(ordstatus).statusdesc rescue ''
  end

  def update_ordproc_status(status)
     self.order_processings.each do |op|
       op.update_attribute(:sent, status)
     end
  end
  
  def check_if_complete
    sent_values = self.order_processings.map(&:sent)
    return if sent_values.include? nil
    return if sent_values.include? 0
    
    #otherwise, its complete
    self.update_attribute(:ordstatus, Constant::ORDER_SHIPPED) 
  end
  
  def reorderable?
    (self.ordstatus == 2 || self.ordstatus == 3 || self.ordstatus == 10) 
  end

  def payment_method
    self.orderpaymentmethod.split(">").second.split("(").first rescue self.orderpaymentmethod.split(">").first.to_s
  end

  def ordered_products
    iop = IscOrderProduct.find(:all, :select => 'orderprodid', :conditions => {:orderorderid => self.orderid})
    order_product_ids_arr = []

    iop.each do |prod|
      order_product_ids_arr << prod.orderprodid.to_s
    end
    
    return order_product_ids_arr
  end

  #for magento orders
  def mage_complete_address
    addr = []
    unless self.shipping_address.nil?
      addr << self.shipping_address['street']
      addr << self.shipping_address['city']
      addr << self.shipping_address['region']
      addr << self.shipping_address['postcode']
      addr << self.shipping_address['country_id']
    end
    addr.join(", ")
  end  
  
  def self.generate_past_3mths_sales_invoice
    live_sites = Site.where("sitename LIKE '%LIVE%' AND sitename NOT LIKE '%Offline%' AND cart_type != 3")  # production, all live sites
    #live_sites = [Site.find(11)] #[Site.find(12), Site.find(16)] #[Site.find(9), Site.find(12), Site.find(16)]  # testing only
    headers = ["Order ID", "Order Date", "Subtotal (¥)", "Shipping Cost (¥)", "Handling Cost (¥)", "Order Total (¥)", "Order Status"]
    
    live_sites.each do |s|
      IscOrder.reconfigure_db(s.id)
      
      orders_1mth_ago = IscOrder.find_by_sql("SELECT orderid, orddate, subtotal_inc_tax, shipping_cost_inc_tax, handling_cost_inc_tax, total_inc_tax FROM isc_orders WHERE ordstatus = 2 AND orddate >= '" + ((Time.now - 1.month).strftime("%Y-%m-01")).to_time.to_i.to_s + "' AND orddate < '" + ((Time.now).strftime("%Y-%m-01")).to_time.to_i.to_s + "' ORDER BY orddate ASC")
      orders_2mth_ago = IscOrder.find_by_sql("SELECT orderid, orddate, subtotal_inc_tax, shipping_cost_inc_tax, handling_cost_inc_tax, total_inc_tax FROM isc_orders WHERE ordstatus = 2 AND orddate >= '" + ((Time.now - 2.month).strftime("%Y-%m-01")).to_time.to_i.to_s + "' AND orddate < '" + ((Time.now - 1.month).strftime("%Y-%m-01")).to_time.to_i.to_s + "' ORDER BY orddate ASC")
      orders_3mth_ago = IscOrder.find_by_sql("SELECT orderid, orddate, subtotal_inc_tax, shipping_cost_inc_tax, handling_cost_inc_tax, total_inc_tax FROM isc_orders WHERE ordstatus = 2 AND orddate >= '" + ((Time.now - 3.month).strftime("%Y-%m-01")).to_time.to_i.to_s + "' AND orddate < '" + ((Time.now - 2.month).strftime("%Y-%m-01")).to_time.to_i.to_s + "' ORDER BY orddate ASC")
      orders_last_3mths = [orders_1mth_ago, orders_2mth_ago, orders_3mth_ago]
      
      filenames = []
      filenames << ("data/accting/sales_invoice/" + s.sitecode + "/" + s.sitecode + "_invoice_" + (Time.now - 1.month).strftime('%m_%Y-%B').to_s + "_gen-" + Time.now.strftime('%Y-%m-%d').to_s + ".xls")
      filenames << ("data/accting/sales_invoice/" + s.sitecode + "/" + s.sitecode + "_invoice_" + (Time.now - 2.month).strftime('%m_%Y-%B').to_s + "_gen-" + Time.now.strftime('%Y-%m-%d').to_s + ".xls")
      filenames << ("data/accting/sales_invoice/" + s.sitecode + "/" + s.sitecode + "_invoice_" + (Time.now - 3.month).strftime('%m_%Y-%B').to_s + "_gen-" + Time.now.strftime('%Y-%m-%d').to_s + ".xls")
      
      i = 0
      
      filenames.each do |fn|
        j = 1
        workbook = Spreadsheet::Workbook.new
        sheet1 = workbook.create_worksheet name: "Sheet1"
        sheet1.row(0).replace headers
      
        if (!orders_last_3mths[i].empty?)
          # data rows
          orders_last_3mths[i].each do |ord|
            sheet1.row(j).replace [ord.orderid, Time.at(ord.orddate).utc.strftime('%Y-%m-%d'), ord.subtotal_inc_tax, ord.shipping_cost_inc_tax, ord.handling_cost_inc_tax, ord.total_inc_tax, "Shipped"]
            j += 1
          end
        
          workbook.write(fn)
        end
        i += 1
      end
      
    end
  end

  def self.generate_past_3mths_mg_sales_invoice
    live_sites = Site.where("sitename LIKE '%LIVE%' AND sitename NOT LIKE '%Offline%' AND cart_type = 3")  # production, all magento live sites
    headers = ["Order ID", "Order Date", "Subtotal (¥)", "Shipping Cost (¥)", "Order Total (¥)", "Order Status"]
    
    live_sites.each do |s|
      @magento = MagentoAPI.new(CONFIG[:magento_pkhost], CONFIG[:magento_user], CONFIG[:magento_key])
      shipped_status = "complete"
      
      orders_1mth_ago = @magento.call("sales_order.list", :status => shipped_status, :created_at => [:like => (Time.now - 1.month).strftime("%Y-%m-%")])  
      orders_2mth_ago = @magento.call("sales_order.list", :status => shipped_status, :created_at => [:like => (Time.now - 2.month).strftime("%Y-%m-%")])
      orders_3mth_ago =  @magento.call("sales_order.list", :status => shipped_status, :created_at => [:like => (Time.now - 3.month).strftime("%Y-%m-%")])
      orders_last_3mths = [orders_1mth_ago, orders_2mth_ago, orders_3mth_ago]
      
      filenames = []
      filenames << ("data/accting/sales_invoice/" + s.sitecode + "/" + s.sitecode + "_invoice_" + (Time.now - 1.month).strftime('%m_%Y-%B').to_s + "_gen-" + Time.now.strftime('%Y-%m-%d').to_s + ".xls")
      filenames << ("data/accting/sales_invoice/" + s.sitecode + "/" + s.sitecode + "_invoice_" + (Time.now - 2.month).strftime('%m_%Y-%B').to_s + "_gen-" + Time.now.strftime('%Y-%m-%d').to_s + ".xls")
      filenames << ("data/accting/sales_invoice/" + s.sitecode + "/" + s.sitecode + "_invoice_" + (Time.now - 3.month).strftime('%m_%Y-%B').to_s + "_gen-" + Time.now.strftime('%Y-%m-%d').to_s + ".xls")
      i = 0
      
      filenames.each do |fn|
        j = 1
        workbook = Spreadsheet::Workbook.new
        sheet1 = workbook.create_worksheet name: "Sheet1"
        sheet1.row(0).replace headers
        if (!orders_last_3mths[i].empty?)
          # data rows
          orders_last_3mths[i].each do |ord|
            sheet1.row(j).replace [ord['increment_id'], ord['created_at'].split(" ")[0], ord['subtotal'].to_f, ord['shipping_amount'].to_f, ord['grand_total'].to_f, "Complete"]
            j += 1
          end
          workbook.write(fn)
        end
        i += 1
      end
    end
  end
  
  def self.get_ws_otids(from_date = nil, to_date = nil, file_name = "")
    responses = []
    page = 1
    num_per_pg = 100 # options available: 20, 50, 100
    cookies = {:cookies => {
      :CK_AUTH_CID => CONFIG[:ck_auth_cid],
      :CK_AUTH_NAME => CONFIG[:ck_auth_name],
      :CK_AUTH_USER => CONFIG[:webshark_id],
      :CK_AUTH_PW => CONFIG[:webshark_pwd],
      :__utma => CONFIG[:utma],
      :__utmz => CONFIG[:utmz],
      :__utmb => CONFIG[:utmb],
      :__utmc => CONFIG[:utmc]}}

#s_type=1&s_word=&s_payment=&s_sy=2013&s_sm=03&s_sd=29&s_ey=2013&s_em=03&s_ed=31&x=103&y=21
#year=&month=&s_status0=&s_status1=&s_status2=&s_status4=&s_status5=&s_status97=&s_status98=&s_word=&s_type=&s_payment=&s_sy=2013&s_sm=03&s_sd=29&s_ey=2013&s_em=03&s_ed=31&num=100   
    options = { 
      "s_sy"  => from_date.year, 
      "s_sm"  => sprintf("%02d", from_date.month), 
      "s_sd"  => sprintf("%02d", from_date.day),
      "s_ey"  => to_date.year, 
      "s_em"  => sprintf("%02d", to_date.month), 
      "s_ed"  => sprintf("%02d", to_date.day), 
      "num"   => num_per_pg.to_s, 
      "page"  => page.to_s
    }
    
    response = RestClient.post(CONFIG[:webshark_orders_url], options, cookies)
    response = response.force_encoding("ASCII-8bit")
    #empty_page = response.gsub(/\r/,"").gsub(/\t/,"").gsub(/\n/,"").split('<font size="3">')[11].split("<br>")[1].include?("\x8AY\x93\x96\x8A\xFA\x8A\xD4\x82\xCC\x92\x8D\x95\xB6\x8F\xEE\x95\xF1\x82\xCD\x8C\xA9\x82\xC2\x82\xA9\x82\xE8\x82\xDC\x82\xB9\x82\xF1\x82\xC5\x82\xB5\x82\xBD\x81B".force_encoding('ASCII-8bit'))
    empty_page = response.include?("\x8AY\x93\x96\x8A\xFA\x8A\xD4\x82\xCC\x92\x8D\x95\xB6\x8F\xEE\x95\xF1\x82\xCD\x8C\xA9\x82\xC2\x82\xA9\x82\xE8\x82\xDC\x82\xB9\x82\xF1\x82\xC5\x82\xB5\x82\xBD\x81B".force_encoding('ASCII-8bit'))
    
    while (!empty_page)
      responses << response
      page += 1
      #{"year"=>Time.current.year, "s_sy"=>from_date.year, "s_sm"=>from_date.month, "s_sd"=>from_date.day,"s_ey"=>to_date.year, "s_em"=>to_date.month, "s_ed"=>to_date.day, "num"=>num_per_pg.to_s, "page"=>page.to_s} 
      options = {"s_sy"=>from_date.year, "s_sm"=>from_date.month, "s_sd"=>from_date.day,"s_ey"=>to_date.year, "s_em"=>to_date.month, "s_ed"=>to_date.day, "num"=>num_per_pg.to_s, "page"=>page.to_s}     
      response = RestClient.post(CONFIG[:webshark_orders_url], options, cookies)
      response = response.force_encoding("ASCII-8bit")
      #empty_page = response.gsub(/\r/,"").gsub(/\t/,"").gsub(/\n/,"").split('<font size="3">')[11].split("<br>")[1].include?("\x8AY\x93\x96\x8A\xFA\x8A\xD4\x82\xCC\x92\x8D\x95\xB6\x8F\xEE\x95\xF1\x82\xCD\x8C\xA9\x82\xC2\x82\xA9\x82\xE8\x82\xDC\x82\xB9\x82\xF1\x82\xC5\x82\xB5\x82\xBD\x81B".force_encoding('ASCII-8bit'))
      empty_page = response.include?("\x8AY\x93\x96\x8A\xFA\x8A\xD4\x82\xCC\x92\x8D\x95\xB6\x8F\xEE\x95\xF1\x82\xCD\x8C\xA9\x82\xC2\x82\xA9\x82\xE8\x82\xDC\x82\xB9\x82\xF1\x82\xC5\x82\xB5\x82\xBD\x81B".force_encoding('ASCII-8bit'))
    end
    
    oids_otids = {}
    
    responses.each do |res|
      page = Nokogiri::HTML(res)
      page.css('table#orderLists table tr').each do |tr|
        id = tr['id']
        next if id.nil?

        oid      = tr.elements[5].elements[0].text
        trans_id = tr.elements[6].elements[0].text
        oids_otids[oid] = trans_id
      end
    end

    csv_file = File.read(Rails.root.join('data','ws_order_data', file_name),:encoding=> "UTF-8").force_encoding("ASCII-8bit")
    csv = CSV.parse(csv_file)
    csv_data = []
    line_num = 0
     
    csv.each do |line|
      line = [((line_num == 0)? "Order Transactions ID" : oids_otids[line[0]])] + line
      
      csv_data << line
      line_num += 1
    end
    
    csv_string = CSV.generate do |csv|
      csv_data.each do |row|
        csv << row
      end
    end
    
    file_name = file_name.split(".csv")
    file_name = file_name[0] + "_2.csv"
    File.open(Rails.root.join('data', 'ws_order_data', file_name), 'w') { |f| f.write(csv_string.force_encoding('UTF-8'))}
    
    return [file_name, oids_otids]
  end
  
  # ENV
  # from_date YYYY-MM-DD
  # to_date   YYYY-MM-DD
  def self.download_ws_order_csvs(from_date=nil, to_date = nil)
    user_id = ENV['user_id']
    site_id = ENV['site_id']

    if from_date.nil?
      if Time.current.beginning_of_week.to_date == Time.current.to_date
        from_date = (Time.current - 3.days).to_date
      else
        from_date = (Time.current - 1.day).to_date
      end
    end 
 
    if to_date.nil?
      to_date = Time.current.to_date
    end 
 
   #from_date = "January 30, 2013".to_date
   #to_date = "January 31, 2013".to_date

    year, month, day = from_date.to_s.split("-")
    year2, month2, day2 = to_date.to_s.split("-")
    
    options = {
        :fixation => 0, :still_fixation => 1, :cancel => 0, :reservation => 0,
        :year => year, :month => month, :day=> day,
        :year2 => year2, :month2 => month2, :day2 => day2,
        :H_ID => CONFIG[:webshark_id], :H_PW => CONFIG[:webshark_pwd],
        :csv_type => Constant::WEBSHARK_FILETYPES['Orders'], :act => 'csv'
      }
    
    response = RestClient.post(CONFIG[:webshark_url], options)
    time = "#{Time.current.hour}-#{Time.current.min}-#{Time.current.sec}"    

    filename = "orders_" + from_date.to_s + "_" + time + '.csv'
    FileUtils.mkpath Rails.root.join('data','ws_order_data') if !File.exists?(Rails.root.join('data','ws_order_data'))
    File.open(Rails.root.join('data','ws_order_data',filename), 'wb'){|f| f << response.to_str}
    Rails.logger.info("Finish downloading file: #{filename} ...")
    
    if File.exist? Rails.root.join('data','ws_order_data',filename)
      #downloading the orders_products.csv file
      options[:csv_type] = Constant::WEBSHARK_FILETYPES['Order Products']
      response = RestClient.post(CONFIG[:webshark_url], options)
      op_filename = "orders_products_" + from_date.to_s + "_" + time + '.csv'
      File.open(Rails.root.join('data','ws_order_data',op_filename), 'wb'){|f| f << response.to_str}
      Rails.logger.info("Finish downloading file: #{op_filename} ...")
      
      file = WebsharkFile.create_new({:filename => filename, :user_id => user_id, :site_id => site_id})

      begin
        lines = File.read(Rails.root.join('data', 'ws_order_data', filename), :encoding => "Shift_JIS")
        csv = CSV.parse(lines)

        csv.each do |row|
          Rails.logger.info(row.inspect)
          orderid = row[0].to_i
          next if orderid == 0

        end
        
      rescue Exception => e
        file.logs = file.logs.to_s + "\n#{e.message.to_s}"
        file.save        
      end
      
    end
    
    fn_oids_otids = IscOrder.get_ws_otids(from_date, to_date, filename)
    return [ fn_oids_otids[0], op_filename ]
  end
  
  def self.ws_orders_to_db(orders_filename = "", order_products_filename = "", site_id = nil)
    ord_prods_hash = {}   # { trxn_id (0) => [product_name (3), product id (4), unit selling price (5), qty (9), WS_sku (10)], ... }
    ords_hash = {}        # { trxn_id (1) => [ ord_trxn_id (0), order_date (2), bill_lastname (4), bill_frstname (5), email (6), bill_zip1-bill_zip2 (7 - 8), bill_state (9), bill_addr1 (10), 
                          #                    bill_addr2 (11), bill_phone (12), ship_lastname (15), ship firstname (16), ship_zip1-shipzip2 (17-18), ship_state (19), ship_addr1 (20), ship_addr2(21), 
                          #                    ship_phone (23), subtotal (30), shipping_cost (31), handling_cost (32), total (35) ] }
    ord_prods_tids_to_insert = []
    
    if (order_products_filename != "" && order_products_filename != nil)
      begin
        lines = File.read(Rails.root.join('data', 'ws_order_data', order_products_filename), :encoding => "SHIFT_JIS")
        csv = CSV.parse(lines)

        csv.each_with_index do |row, ln|
          Rails.logger.info(row.inspect)
          next if (ln == 0)
          if (ord_prods_hash[row[0].to_i] == nil) 
            ord_prods_hash[row[0].to_i] = [ row[3], row[4].to_i, row[5].to_f, row[9].to_i, row[10] ]
          else
            ord_prods_hash[row[0].to_i] = ord_prods_hash[row[0].to_i] + [ row[3], row[4].to_i, row[5].to_f, row[9].to_i, row[10] ]
          end
        end
      rescue Exception => e
        puts "\n#{e.message.to_s} ==> Parse Order Products File"
      end
      
      begin
        lines = File.read(Rails.root.join('data', 'ws_order_data', orders_filename), :encoding => "SJIS-SoftBank")
        csv = CSV.parse(lines)

        csv.each_with_index do |row, ln|
          next if (ln == 0)
          if (ords_hash[row[1].to_i] == nil) 
            ords_hash[row[1].to_i] = [ row[0].to_i, row[2], row[4], row[5], row[6], row[7], row[8], row[9], row[10], row[11], row[12], row[15], row[16], row[17], row[18], row[19], row[20], row[21], row[23], row[30].to_f, row[31].to_f, row[32].to_f, row[35].to_f, row[41] ]
          else
            ords_hash[row[1].to_i] = ords_hash[row[1].to_i] + [ row[0].to_i, row[2], row[4], row[5], row[6], row[7], row[8], row[9], row[10], row[11], row[12], row[15], row[16], row[17], row[18], row[19], row[20], row[21], row[23], row[30].to_f, row[31].to_f, row[32].to_f, row[35].to_f, row[41] ]
          end
        end
      rescue Exception => e
        puts "\n#{e.message.to_s} ==> Parse Orders File"
      end    
    end
    
    IscOrder.reconfigure_db(site_id)
    
    ords_hash.each do |tid, details|
      cust = IscCustomer.where("custconemail = '" + details[4] + "'").first
      if (cust == nil)
        cust = IscCustomer.new(:custconfirstname => details[3], :custconlastname => details[2], :custconemail => details[4], :custconphone => details[10], :custdatejoined => Time.current.to_i, :custlastmodified => Time.current.to_i)
      else
        cust.update_attributes(:custconfirstname => details[3], :custconlastname => details[2], :custconemail => details[4], :custconphone => details[10], :custlastmodified => Time.current.to_i)
      end
      cust.save
      cust = IscCustomer.where("custconemail = '" + details[4] + "'").first
      customerid = cust.customerid

      order_addr = IscOrderAddress.where("order_id = " + details[0].to_s.rjust(8, '9')).first
      if (order_addr == nil) 
        zip = (details[13] != nil && details[13] != "")? (details[13].to_s + "-" + details[14].to_s) : (details[5].to_s + "-" + details[6].to_s)

        order_addr = IscOrderAddress.new(:order_id => details[0].to_s.rjust(8, '9').to_i, :first_name => (details[12] != nil && details[12] != "")? details[12] : details[3], 
                       :last_name => (details[11] != nil && details[11] != "")? details[11] : details[2], :address_1 => (details[16] != nil && details[16] != "")? details[16] : details[8], 
                       :address_2 => (details[17] != nil && details[17] != "")? details[17] : details[9], :zip => zip, 
                       :state => (details[15] != nil && details[15] != "")? details[15] : details[7], :email => details[4], :phone => details[10]) #:total_items => <count number of items ordered>
        order_addr.save!
        order_addr.reload
        order = IscOrder.new(:orderid => details[0].to_s.rjust(8, '9').to_i, :ordcustid => customerid, :orddate => details[1].to_datetime.to_i, :ordlastmodified => Time.current.to_i, :subtotal_ex_tax => details[19], 
                  :subtotal_inc_tax => details[19], :base_shipping_cost => details[20], :shipping_cost_ex_tax => details[20], :shipping_cost_inc_tax => details[20], :base_handling_cost => details[21],
                  :handling_cost_ex_tax => details[20], :handling_cost_inc_tax => details[20], :handling_cost_tax => details[20], :base_wrapping_cost => details[20], :wrapping_cost_inc_tax => details[20],
                  :wrapping_cost_ex_tax => details[20], :wrapping_cost_tax => details[20], :total_ex_tax => details[22], :total_inc_tax => details[22], 
                  :ordstatus => Constant::ORDER_UNPAID, :orderpaymentmethod => details[18], 
                  :ordbillfirstname => details[3], :ordbilllastname => details[2], :ordbillstreet1 => details[8], :ordbillstreet2 => details[9], :ordbillsuburb => "", :ordbillstate => details[7], 
                  :ordbillzip => (details[5].to_s + "-" + details[6].to_s), :ordbillphone => details[10], :ordbillemail => details[4], :ordisdigital => false, :ordtrackingno => "", :deleted => false, 
                  :ordnotes => "WS Transaction ID: _" + tid.to_s + "_") # :ordtotalshipped => 0, :ordtotalqty => <count number of items ordered>

        order.orderid =  details[0].to_s.rjust(8, '9').to_i
        order.save!
        
        shipping = IscOrderShipping.new(:order_address_id => order_addr.id, :order_id =>  details[0].to_s.rjust(8, '9').to_i)
        shipping.save!
        ord_prods_tids_to_insert << tid
      end
    end
    
    ord_prods_hash.each do |tid, val|
      if (ord_prods_tids_to_insert.include?(tid))
        order = IscOrder.where("ordnotes LIKE '%_" + tid.to_s + "_%'").first

        i = 0
        oaid = order.isc_order_address.id
        while (i < val.count)
          order_product = IscOrderProduct.new(:ordprodsku => val[i+4].strip, :ordprodname => val[i].strip, :base_price => val[i+2], :price_ex_tax => val[i+2], :price_inc_tax => val[i+2], :base_total => val[i+2],
                            :total_ex_tax => val[i+2], :total_inc_tax => val[i+2], :ordprodqty => val[i+3], :orderorderid => order.orderid, :ordprodid => val[i+1], :order_address_id => oaid)
          order_product.save
          i += 5
        end        
        
        #order_product = IscOrderProduct.new(:ordprodsku => val[4], :ordprodname => val[0].strip, :base_price => val[2], :price_ex_tax => val[2], :price_inc_tax => val[2], :base_total => val[2],
        #                  :total_ex_tax => val[2], :total_inc_tax => val[2], :ordprodqty => val[3], :orderorderid => order.orderid, :ordprodid => val[1], :order_address_id => order.isc_order_address.id)
        order_product.save
      end
    end
    
  end
  
  def self.cron_get_ws_data
    filenames = IscOrder.download_ws_order_csvs
    IscOrder.ws_orders_to_db(filenames[0], filenames[1], 17)
    SmGcTransaction.get_paid_orders # credit card orders
  end
  
end
