class SmGcTransaction < ActiveRecord::Base
  
  simple_audit do |gc_trxn|
    {
        :order_id => gc_trxn.order_id,
        :site_id => 16, #(Site.current_site.id rescue nil),
        :is_visible => gc_trxn.is_visible,
        :notes => gc_trxn.notes,
        :username_method => User.current
    }
  end
  
  def self.get_paid_orders
    IscOrder.reconfigure_db(17)
    puts "ABC"
    unpaid_orders = IscOrder.where("ordstatus = " + Constant::ORDER_UNPAID.to_s)
    unpaid_oids = []
    
    unpaid_orders.each do |ord|
      if (ord.orderid.to_s[0..1] == "99")
        unpaid_oids << ord.orderid.to_s[2..(ord.orderid.to_s.length - 1)]
      else
        unpaid_oids << ord.orderid.to_s[1..(ord.orderid.to_s.length - 1)]
      end
    end
    
    puts unpaid_oids.inspect
    
    IscOrder.reconfigure_db(16)
    #payment_details = SmGcTransaction.where("order_id IN (" + unpaid_oids.join(",") + ") AND response_order_status LIKE '%<STATUSID>800</STATUSID>%'")
    payment_details = SmGcTransaction.where("order_id IN ('" + unpaid_oids.join("','") + "') AND response_order_status LIKE '%<STATUSID>800</STATUSID>%'")
    paid_oids = payment_details.collect { |pd| pd.order_id.to_s.rjust(8, '9').to_i }
    
    puts payment_details.inspect
    puts paid_oids.inspect
    
    IscOrder.reconfigure_db(17)
    unless paid_oids.empty?
      paid_orders = IscOrder.where("orderid IN (" + paid_oids.join(",") + ")")
      paid_ords = []
      paid_ord_ids = []
      
      puts paid_orders.inspect

      IscOrder.reconfigure_db(16)
      paid_orders.each do |ord|
        otid = (ord.orderid.to_s[0..1] == '99')? ord.orderid.to_s[2..7] : ord.orderid.to_s[1..7] 
        puts "OTID: " + otid
        payment = payment_details.select { |pm| (puts pm.order_id.to_s + " == " + otid.to_s); pm.order_id == otid }
        puts payment.inspect
        if (!payment.empty?)
          payment = payment[0]
          payment_amt = payment.response_order_status.split("<AMOUNT>")[1].split("</AMOUNT>")[0].to_f / 100
          puts "ord.total_inc_tax.to_f == payment_amt => " + (ord.total_inc_tax.to_f == payment_amt).inspect
          if (ord.total_inc_tax.to_f == payment_amt)
            paid_ords << ord
            paid_ord_ids << ord.orderid
          end
        end
      end
      
      puts paid_ords.inspect
      puts paid_ord_ids.inspect
      
      if (!paid_ord_ids.empty?)
        IscOrder.reconfigure_db(17)
        #saved = IscOrder.update_all(("ordstatus = " + Constant::ORDER_PAID.to_s), "orderid IN (" + paid_ord_ids.join(",") + ")")
        #paid_orders = IscOrder.where("orderid IN (" + paid_ord_ids.join(",") + ")")
        
        #paid_orders.each do |pord|
        paid_ords.each do |pord|
          pord.ordstatus = 11
          pord.save!
          IscOrder.status_update_email(pord, 17)
        end
      end
    end
  end
  
  def self.format_form_response(trxn)
    if (!trxn.response_for_form.blank?)
      name = trxn.response_for_form.split("<FIRSTNAME>")[1].split("</FIRSTNAME>")[0] + " " + trxn.response_for_form.split("<SURNAME>")[1].split("</SURNAME>")[0]
      email = trxn.response_for_form.split("<EMAIL>")[1].split("</EMAIL>")[0]
    end
    
    return "<strong>NAME:</strong> " + name + ",&nbsp;&nbsp;&nbsp;<strong>Email:</strong> " + email + "<br/>"
  end
  
  def self.format_order_status_response(trxn)
    if (!trxn.response_for_form.blank?)
      oid = trxn.response_order_status.split("<ORDERID>")[1].split("</ORDERID>")[0]
      amount = (trxn.response_order_status.split("<AMOUNT>")[1].split("</AMOUNT>")[0].to_i / 100).to_s
      result = trxn.response_order_status.split("<RESULT>")[1].split("</RESULT>")[0]
      Rails.logger.info(trxn.response_order_status.inspect)
      status_id = trxn.response_order_status.split("<STATUSID>")[1].split("</STATUSID>")[0] rescue ""
    end
    
    return "<strong>Order ID:</strong> " + oid + ",&nbsp;&nbsp;&nbsp;<strong>Amount:</strong> " + amount + ",&nbsp;&nbsp;&nbsp;<strong>Result:</strong> " + result + ",&nbsp;&nbsp;&nbsp;<strong>Status ID:</strong> " + status_id
  end
  
  def self.format_cancel_response(trxn)
    if (!trxn.response_for_cancel_payment.blank?)
      result = trxn.response_for_cancel_payment.split("<RESULT>")[1].split("</RESULT>")[0]
    end
    
    return (result == "OK")? "<br/><strong style='color: red'><i>Payment Canceled</i></strong>" : ""
  end
  
  def self.get_total_payments_collected(date = Time.current.strftime("%Y-%m-01"))
    IscOrder.reconfigure_db(16)
    trxns = SmGcTransaction.where("response_order_status LIKE '%<RESPONSE><RESULT>OK</RESULT>%<STATUSID>800</STATUSID>%' AND date_time >= '" + date + "' AND date_time < '" + (date.to_date + 1.month).strftime("%Y-%m-01") + "'")
    payment_amts = trxns.collect { |trxn| (trxn.response_order_status.split("<AMOUNT>")[1].split("</AMOUNT>")[0].to_f / 100.0) }
    return [trxns, payment_amts, payment_amts.inject(0.0,:+)]
  end
  
end
