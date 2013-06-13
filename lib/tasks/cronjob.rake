namespace :cronjob do

  desc "Clean fragment cache"
  task :clean_fragment_cache => :environment do
    Site.all.each do |site|
      Rails.cache.delete("views/#{site.id}-preview_supplier_order_data")
    end
    puts "Done removing all fragment cache..."
  end

  desc "Update order status"
  task :order_status_checker => :environment do
    Site.enabled.each do |site|
      IscOrder.reconfigure_db(site.id)
      orders = IscOrder.where("ordstatus = ? AND DATE_FORMAT(created_at, '%Y-%m-%d') >= ?", IscOrder::STATUS["Submitted"].first.to_i, Constant::APP_STARTING_DATE)
      orders.each do |order|
        #TODO
      end
    end
  end

  desc "Get new orders from Magento site"
  task :magento_orders => :environment do
    require 'savon'
    
    Savon.configure do |config|
      config.log = false            # disable logging
      config.logger = Rails.logger  # using the Rails logger
    end
    @@client = Savon::Client.new do
      wsdl.document = CONFIG[:magento_pk]
    end
    
    # Get session token
    begin
      response = @@client.request :login do
        soap.body ={ :username => CONFIG[:magento_user], :apiKey => CONFIG[:magento_key] }
      end
    rescue Exception => e
      raise "ERROR: #{e.message.inspect}"    
    end
    raise "Login failed..." if response.success? == false
    @@session =  response[:login_response][:login_return]
    
    # Get sales order list
    order_request = @@client.request :call do
      soap.body = { :session => @@session, :method => 'sales_order.list' }
    end


    #************ helper methods *************************************
      def self.get_customer_info(customer_id)
        puts "Getting info for customer id : #{customer_id}.............."
        cust = {}
        return cust if customer_id.blank?
        
        response = @@client.request :call do
          soap.body = { :session => @@session, :method => 'customer.info', :customerId => customer_id }
        end
        
        if response.success?
          info = response[:call_response][:call_return][:item]
          cust[:custconphone]  = ""            
          cust[:custdatejoined] = Mage.get_value("created_at", info).to_time.to_i
          cust[:custlastmodified] = Mage.get_value("updated_at", info).to_time.to_i
          cust[:store_id] = Mage.get_value("store_id", info)
          cust[:website_id] = Mage.get_value("website_id", info)
          cust[:custconfirstname] = Mage.get_value("firstname", info)
          cust[:custconlastname] = Mage.get_value("lastname", info)
          cust[:custconemail] = Mage.get_value("email", info)
        end

        puts "Done getting customer info..."
        return cust
      end
      
      def self.get_status(status)
        case status.to_s
        when "pending", "pending_ogone"
          1
        when "complete"
          2
        when "canceled"
          4
        when "pending_payment", "payment_review"
          7
        when "processing", "processing_ogone"
          11
        when "submitted"
          9
        when "partially_shipped"
          3
        else
          1
        end  
      end
      
      def self.get_order_details(order_arr)
        ret = { :order => {},
                :customer => {},
                :order_products => [],
                :order_address => {}
              }
        increment_id = nil
        puts order_arr.inspect 
        increment_id = Mage.get_value("increment_id", order_arr)
        ret[:order][:increment_id] = increment_id
        ret[:order][:mage_order_id] = Mage.get_value("order_id", order_arr)
        ret[:order][:orderid] = increment_id.to_i
        customer_id = Mage.get_value("customer_id", order_arr)
        ret[:customer] = get_customer_info(customer_id)            
        ret[:order][:orddate] = Mage.get_value("created_at", order_arr).to_time.to_i
        ret[:order][:ordlastmodified] = Mage.get_value("updated_at", order_arr).to_time.to_i
        total = Mage.get_value("grand_total", order_arr)
        ret[:order][:subtotal_ex_tax] = total
        ret[:order][:subtotal_inc_tax] = total
        ret[:order][:total_ex_tax] = total
        ret[:order][:total_inc_tax] = total
        ret[:order][:ordstatus] = Helpers.mage_to_isc_ordstatus(Mage.get_value("status", order_arr))
        ret[:order][:ordbillfirstname] = Mage.get_value("billing_firstname", order_arr)
        ret[:order][:ordbilllastname] = Mage.get_value("billing_lastname", order_arr)
        ret[:order][:store_id] = Mage.get_value("store_id", order_arr)


        #get order info
        puts "Getting Order info order_id #{increment_id}"
        unless increment_id.blank?
          response = @@client.request :call do
            soap.body = { :session => @@session, :method => 'sales_order.info', :orderIncrementId => increment_id }
          end
          
          if response.success?
            order_info = response[:call_response][:call_return][:item]
            payment_info = Mage.get_value("payment", order_info)
            
            ret[:order][:orderpaymentmethod] = Mage.get_value("method", payment_info[:item])

            puts "setting SHIPPING ADDRESS.........................."
            shipping_info = Mage.get_value("billing_address", order_info)

            ret[:order_address][:mage_billing_id] = Mage.get_value("increment_id", shipping_info[:item])
            telno = Mage.get_value("telephone", shipping_info[:item])
            ret[:order_address][:phone] = telno
            ret[:customer][:custconphone]  = telno
            ret[:order][:ordbillphone] = telno
            ret[:order_address][:first_name] = Mage.get_value("firstname", shipping_info[:item])
            ret[:order_address][:last_name] = Mage.get_value("lastname", shipping_info[:item])
            ret[:order_address][:address_1] = Mage.get_value("street", shipping_info[:item])
            ret[:order][:ordbillstreet1] = Mage.get_value("street", shipping_info[:item])
            ret[:order][:ordbillstreet2] = ""
            ret[:order_address][:zip] = Mage.get_value("postcode", shipping_info[:item])
            ret[:order][:ordbillzip] = Mage.get_value("postcode", shipping_info[:item])
            ret[:order_address][:state] = Mage.get_value("region", shipping_info[:item])
            ret[:order][:ordbillstate] = Mage.get_value("region", shipping_info[:item])
            ret[:order_address][:email] = Mage.get_value("email", shipping_info[:item])
            ret[:order][:ordbillemail] = Mage.get_value("email", shipping_info[:item])
            ret[:order_address][:city] = Mage.get_value("city", shipping_info[:item])
            ret[:order_address][:company] = Mage.get_value("company", shipping_info[:item])
            ret[:customer][:custconcompany] = Mage.get_value("company", shipping_info[:item])
            ret[:order][:ordbillsuburb] = ""                  
            ret[:order][:ordtrackingno] = ""
            
            puts "Collecting ordered items/products"
            items = Mage.get_value("items", order_info)
            ordered_items = []
            
            if items[:item].class == Hash
              ordered_items << items[:item]
            else
              ordered_items = items[:item]
            end
            
            ordered_items.each do |item|
              prod_info = {}
              item_row = item[:item]
              
              prod_info[:mage_item_id] = Mage.get_value("item_id", item_row)
              prod_info[:ordprodsku] = Mage.get_value("sku", item_row)
              prod_info[:ordprodname] = Mage.get_value("name", item_row)
              price = Mage.get_value("price", item_row)
              prod_info[:base_price] = price
              prod_info[:price_ex_tax] = price
              prod_info[:price_inc_tax] =price
              prod_info[:base_total]  = price
              prod_info[:total_ex_tax]  = price
              prod_info[:total_inc_tax]  = price
              prod_info[:ordprodqty] = Mage.get_value("quote_item_id", item_row)
              prod_info[:ordprodid] = Mage.get_value("product_id", item_row)
              ret[:order_products] << prod_info unless prod_info.empty?
            end
            
          end
        end
  
        return ret
      end
    
    #***********  end of helper methods ***********************************
    

    # fetching all orders
    if order_request.success?
      order_request[:call_response][:call_return][:item].each do |order|
        order = order[:item]
        order_details = get_order_details(order)

        next if order_details[:customer][:custconemail].nil?
        Mage.insert_order(order_details)
      end
    end

  end
  
  #desc "Get Product List from Magento"
  #task :magento_products => :environment do
  #  require 'savon'
  #  
  #  Savon.configure do |config|
  #    config.log = false            # disable logging
  #    config.logger = Rails.logger  # using the Rails logger
  #  end
  #  
  #  @@client = Savon::Client.new do
  #    wsdl.document = CONFIG[:magento_pk]
  #  end
    
    # Get session token
  #  begin
  #    response = @@client.request :login do
  #      soap.body ={ :username => CONFIG[:magento_user], :apiKey => CONFIG[:magento_key] }
  #    end
  #  rescue Exception => e
  #    raise "ERROR: #{e.message.inspect}"    
  #  end
  #  raise "Login failed..." if response.success? == false
  #  @@session =  response[:login_response][:login_return]

  #  cr = @@client.request :call do
  #    soap.body = { :session => @@session, :method => 'catalog_product.list' }
  #  end

  #  cr[:call_response][:call_return][:item].each do |prod|
  #    product = prod[:item]
  #    product_id = Mage.get_value("product_id", product)
  #    name = Mage.get_value("name", product)
  #    sku = Mage.get_value("sku", product)
  #    puts product_id + ", " + name + ", " + sku
  #  end
  #end
  
end
