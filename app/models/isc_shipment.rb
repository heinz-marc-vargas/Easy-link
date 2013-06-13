class IscShipment  < ActiveRecord::Base
  set_primary_key :shipmentid
  belongs_to :isc_order, :foreign_key => "orderid"

  simple_audit do |is_record|
    {
        :shipmentid => is_record.shipmentid,
        :shipcustid => is_record.shipcustid,
        :shipvendorid => is_record.shipvendorid,
        :shipdate => (is_record.shipdate rescue nil),
        :shiptrackno => is_record.shiptrackno,
        :shipping_module => (is_record.shipping_module rescue nil),
        :shipmethod => is_record.shipmethod,
        :shiporderid => is_record.shiporderid,
        :shiporderdate => (is_record.shiporderdate rescue nil),
        :shipcomments => is_record.shipcomments,
        :shipbillfirstname => is_record.shipbillfirstname,
        :shipbilllastname => is_record.shipbilllastname,
        :shipbillcompany => is_record.shipbillcompany,
        :shipbillstreet1 => is_record.shipbillstreet1,
        :shipbillstreet2 => is_record.shipbillstreet2,
        :shipbillsuburb => is_record.shipbillsuburb,
        :shipbillstate => is_record.shipbillstate,
        :shipbillzip => is_record.shipbillzip,
        :shipbillcountry => is_record.shipbillcountry,
        :shipbillcountrycode => is_record.shipbillcountrycode,
        :shipbillcountryid => is_record.shipbillcountryid,
        :shipbillstateid => is_record.shipbillstateid, 
        :shipbillphone => is_record.shipbillphone,
        :shipbillemail => is_record.shipbillemail,
        :shipshipfirstname => is_record.shipshipfirstname,
        :shipshiplastname => is_record.shipshiplastname,
        :shipshipcompany => is_record.shipshipcompany,
        :shipshipstreet1 => is_record.shipshipstreet1,
        :shipshipstreet2 => is_record.shipshipstreet2,
        :shipshipsuburb => is_record.shipshipsuburb,
        :shipshipstate => is_record.shipshipstate,
        :shipshipzip => is_record.shipshipzip,
        :shipshipcountry => is_record.shipshipcountry,
        :shipshipcountrycode => is_record.shipshipcountrycode,
        :shipshipcountryid => is_record.shipshipcountryid,
        :shipshipstateid => is_record.shipshipstateid,
        :shipshipphone => is_record.shipshipphone,
        :shipshipemail => is_record.shipshipemail,        
        :site_id => (Site.current_site.id rescue nil),
        :username_method => User.current
    }
  end
  
  class << self
    def reconfigure_db(site_id)
      isc_site = Site.find(site_id)
      IscShipment.establish_connection(isc_site.database_config.decrypted_attr)
    end
    
    def get_shipment(order_id)
      IscShipment.where("shiporderid = ?", order_id).first
    end
    
    def create_shipments(order_id, isds = [])
      begin
puts "create_shipments : #{order_id}"

      return nil if order_id.nil?
      ret_shipments = []
      Rails.logger.info("Creating IscShipment... order_id: #{order_id}, isds: #{isds.inspect}")

      ship_vendor_id = 0
      ship_date = isds.first.ship_date.to_time.to_i rescue nil
      order = IscOrder.find(order_id.to_i) rescue nil

      if ship_date.nil?
        RedMailer.delay(:queue => "emails").notifier("Error: ISDs: #{isds.inspect} \n #{isds.first.inspect}")
      end

      if order.nil?
        Rails.logger.info("ISC ORDER ID #{order_id} DOESN'T EXISTS....")
        return nil
      end
      
      shipping = IscOrderShipping.find_by_order_id(order_id.to_i)  rescue nil
      order_addr = order.isc_order_address
      tracking_nums = isds.map(&:tracking_num)
      ship_comments = tracking_nums.join(",")
      ship_track_nums = tracking_nums.take(3).join(",") #to limit no. of characters allowed in isc

      isds.each do |isd|
        shipments = IscShipment.where("shiporderid=? AND shiptrackno = ?", order_id, isd.tracking_num)


        if shipments.empty? 
          shipment = IscShipment.new(:shipcustid => order.ordcustid, :shipvendorid => ship_vendor_id, :shipdate => ship_date, :shiptrackno => isd.tracking_num, 
                  :shipping_module => (shipping.module.to_s rescue ''), :shipmethod => (shipping.method.to_s rescue ''), :shiporderid => order_id, :shiporderdate => order.orddate.to_i,
                  :shipcomments => ship_comments, :shipbillfirstname => order.ordbillfirstname.to_s, :shipbilllastname => order.ordbilllastname.to_s, 
                  :shipbillcompany => (order.ordbillcompany.to_s rescue ' '), :shipbillstreet1 => order.ordbillstreet1.to_s, :shipbillstreet2 => order.ordbillstreet2.to_s, 
                  :shipbillsuburb => order.ordbillsuburb, :shipbillstate => order.ordbillstate, :shipbillzip => order.ordbillzip, 
                  :shipbillcountry => order.ordbillcountry.to_s, :shipbillcountrycode => order.ordbillcountrycode, :shipbillcountryid => order.ordbillcountryid,
                  :shipbillstateid => order.ordbillstateid, :shipbillphone => order.ordbillphone.to_s, :shipbillemail => order.ordbillemail.to_s,
                  :shipshipfirstname => order_addr.first_name.to_s, :shipshiplastname => order_addr.last_name.to_s, :shipshipcompany => order_addr.company.to_s,
                  :shipshipstreet1 => order_addr.address_1.to_s, :shipshipstreet2 => order_addr.address_2.to_s, :shipshipsuburb => order_addr.city.to_s, 
                  :shipshipstate => order_addr.state, :shipshipzip => order_addr.zip, :shipshipcountry => order_addr.country,
                  :shipshipcountrycode => order_addr.country_iso2, :shipshipcountryid => order_addr.country_id, :shipshipstateid => order_addr.state_id,
                  :shipshipphone => order_addr.phone, :shipshipemail => order_addr.email)
puts shipment.inspect

          if shipment.save
puts "already saved..."
            IscShipmentItem.create_shipment_items(order_id, shipment.shipmentid)
            ret_shipments << shipment
          else
            Rails.logger.info("ERROR: IscShipment.rb create_shipment. Orderid: #{order_id}, isd_ids: #{isds.map(&:id).to_s}")
          end
        else
          #assume one shipments found
          IscShipmentItem.create_shipment_items(order_id, shipments.first.shipmentid)
        end
      end
     
      return ret_shipments

      rescue Exception => e
        puts "Error: #{e.message} -------------------------------"
        RedMailer.delay(:queue => "emails").notifier("Error: IscShipment.create_shipments (#{order_id}) - #{e.message}")
      end
    end
    
  end
  
end
