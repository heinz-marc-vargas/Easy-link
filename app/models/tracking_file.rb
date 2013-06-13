class TrackingFile < ActiveRecord::Base
  belongs_to :uploader, :polymorphic => true
  attr_accessor :processed_counter

  STATUS = {
    :pending => "Pending",
    :processing => "Processing",
    :failed => "Failed"
  }
  
  class << self
    def process_file(id)
      return nil if id.nil?
      tf = TrackingFile.find(id) rescue nil
      return nil if tf.nil?
      filename = tf.filename
      
      begin
        Rails.logger.info("Starting to process...")
        tf.update_attribute(:status, "Processing")
        fname_arr = tf.filename.split("_")
        
        if fname_arr.first == "SV" #sava
          Rails.logger.info("PARSE SAVA")
          isd_orders = XlsParser.sava_parser(filename)
        elsif fname_arr.first == "WM"  #westmead
          Rails.logger.info("Westmead")
          isd_orders = XlsParser.westmead_parser(filename)
        else
          Rails.logger.info("Format of your filename is invalid.")
          raise "Format of your filename is invalid."
        end
  
        Rails.logger.info("ISD_ORDERS: #{isd_orders.map(&:id).inspect} \n\n")
        #updating isc
        group_isd = isd_orders.group_by(&:order_id)
        Rails.logger.info("ISD_ORDERS_GROUP: " + group_isd.keys.inspect)
  
        prev_site_id = nil
        used_site_id = nil
        group_isd.each do |order_id, isds|
          puts "isds: #{isds.inspect}"
          next if isds.empty?

          Rails.logger.info("#{order_id} and #{isds} *************************")
          site_id = Helpers.get_site_id(order_id)
          Rails.logger.info("site_id: #{site_id}")
  
          unless site_id.nil?
            Rails.logger.info("site_id not nil")
            osite = Site.find(site_id)
            Rails.logger.info("ps=#{prev_site_id} === sss_id=#{site_id}")

            unless prev_site_id.nil?
              if prev_site_id.to_i != site_id.to_i
                used_site_id = site_id
                IscOrder.reconfigure_db(site_id)
                Rails.logger.info("reconfigured db...")
              else
                used_site_id = prev_site_id
                IscOrder.reconfigure_db(prev_site_id)
                Rails.logger.info("prev_site reconfigured db...")
              end
            else
              used_site_id = site_id
              IscOrder.reconfigure_db(site_id)
              Rails.logger.info("reconfigured db...")
              prev_site_id = site_id
            end

            order = IscOrder.find(order_id) rescue nil
            if order.nil?
              Rails.logger.info("\n::::::::::::::: ORDER NIL: #{order_id}")
              RedMailer.delay(:queue => "others").notifier("ERROR: TrackingFile.process_file(#{id}); order_id: #{order_id} used_site_id: #{used_site_id} ")
              next if order.nil?
            else
              Delayed::Worker.logger.info("\n\norder: #{order.inspect}")
            end
  
            puts "\n\n creating IscShipment..."
            puts isds.first.inspect

            order.orddateshipped = isds.first.ship_date.to_time.to_i rescue nil
            IscShipment.create_shipments(order_id, isds) if site_id != 18
            puts "done creating isc_shipment..."
            Rails.logger.info("IscShipment created...\n")
            orig_status = order.ordstatus 
  
            if order.all_ordered?
              Rails.logger.info("===>>>> All ordered: #{order.inspect}")
              Delayed::Worker.logger.info("===>>>> All ordered: #{order.inspect}")

              order.update_attribute(:ordstatus, IscOrder::STATUS["Shipped"].first.to_i)

              if site_id == 17
                if orig_status.to_i != order.ordstatus.to_i
                  IscOrder.delay(:queue => "others").set_webshark_status(order.orderid, site_id, Constant::WS_CONFIRM_ID)
                end
              elsif site_id == 18 #PKY
                Mage.delay(:queue => "others").create_shipment(order.orderid, site_id, 0)
                Mage.delay(:queue => "others").update_status(order.orderid, site_id, order.ordstatus)
              else
                if orig_status == 2 && order.ordstatus != 2 && order.ordstorecreditassigned == 1
                  order.unset_credits
                else
                  if order.ordstorecreditassigned == 0 && order.ordstatus == 2
                    order.set_credits
                  end
                end
              end
            else
              Rails.logger.info("-->> Not yet all ordered: #{order.inspect}")
              order.update_attribute(:ordstatus, IscOrder::STATUS["Partially Shipped"].first.to_i) if order.ordstatus.to_i != 2
              Mage.delay(:queue => "others").update_status(order.orderid, site_id, order.ordstatus) if site_id == 18 #PKY              
            end
          
            if orig_status != order.ordstatus
              IscOrder.status_update_email(order, site_id)

              #referral store credit
              begin
                ir = IscReferral.where("status=2 AND orderid=?", order.orderid).first rescue nil
                unless ir.nil?
                  expiredays   = Helpers.get_scr_expiry(site_id)
                  max_date     = order.orddateshipped - expiredays.days
                  date_invited = Time.at(ir.date_invited).to_date
                
                  if date_invited >= Time.at(max_date).to_date
                    referrer = IscCustomer.find(ir.customer_id)
                    new_credit = referrer.custstorecredit.to_i + ir.referrer_storecreditearned.to_i
                    referrer.update_attribute(:custstorecredit, new_credit)
                    ir.status = 3
                    ir.date_purchased = order.orddateshipped
                    ir.save!
                    log_sc = IscCustomerCredits.new(:customerid => referrer.id, :creditamount => new_credit.to_f,
                          :credittype => 'referral', :creditdate => Time.current.to_i, :credituserid => 0, 
                          :creditreason => "OC: Referral store credit. IscReferral ID: #{ir.id} Order ID: #{order.orderid}")
                    log_sc.save!
                  end
                end
              rescue Exception => e
                RedMailer.delay(:queue => "emails").notifier("IscReferral: #{e.message}; orderid:#{order.orderid} site:#{site_id}")
              end
              
            else
              new_email_sent = false
              isds.each do |isd|
                if isd.is_new && !new_email_sent
                  IscOrder.status_update_email(order, site_id)
                  new_email_sent = true
                end
              end
            end
  
            if osite.sitecode != Constant::KX_CODE
              puts "    entering updating ordtrackingno..."
              all_isds = IscShipmentData.where("order_id = ?", order_id.to_i)
              order.ordtrackingno = all_isds.map(&:tracking_num).uniq.join(",")
              Rails.logger.info("Updating ordtrackingno= #{order.ordtrackingno}")
            end
 
            order.save!           
          end
        end

        Delayed::Worker.logger.info("DONE...")
        tf.update_attribute(:status, "Success")
      
      rescue Exception => e
        puts "Error: #{e.message} ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
        Rails.logger.info("Error: #{e.message} ")
        RedMailer.delay(:queue => "emails").notifier("Error: TrackingFile.process_file(#{tf.id}) - #{e.message}")
        tf.logs = tf.logs.to_s + "\n" + e.message.to_s
        tf.update_attribute(:status, "Failed")
        tf.save
      rescue Timeout::Error => te
        Rails.logger.info("Rescued from timeout : #{te}")
      end
       
     end
   end
end
