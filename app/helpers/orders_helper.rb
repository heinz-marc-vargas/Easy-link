module OrdersHelper
  
  def show_order_status(ordstatus)
    Constant::ORDER_STATUSES.each do |key, values|
      return key.to_s if values.include? ordstatus.to_s    
    end
    return ''
  end
  
  def response_success?(ots)
    return false if ots.nil?
    return false if ots.response_status.nil?
    return true if ots.response_status.to_s == "ok"
    return true if ots.response_status.inspect.to_s.include?('Success')
    false 
  end
  
  def show_response_message(ots)
    return "" if ots.response_status.nil?

    result = ots.response_status.to_s.split("\n")
    if result.length == 11
      str = result[9].to_s.gsub("  - ", '')
      str = str.gsub("\r", "")
      return str.inspect.to_s
    else
      return ots.response_status.inspect.to_s  
    end
  end
  
  def commify(str)
    str.reverse.gsub(/(\d\d\d)(?=\d)(?!\d*\.)/,'\1,').reverse
  end

  def get_payment_method(order)
    return '' if order.nil?  
    return '' if order.orderpaymentmethod.nil?
    payment = order.orderpaymentmethod.split("images/")
    
    if !payment.empty? && payment.length == 2
      return payment[1].split(".")[0]
    else
      return order.orderpaymentmethod
    end
  end
  
  def current_site_logo(height="25")
    return '' if @site.nil?
    return '' if @site.logo.nil?  
    return image_tag "/images/sites/#{@site.logo}", :height => height
  end
  
  def show_split_qty(order_process)
    return '' if order_process.nil?
    return '' if order_process.qty.nil?
    return '' if order_process.qty.to_i <= 10 && order_process.split_by_val.nil?
    
    options = [["no split","--"]]

    if order_process.split_by_val.nil?
      i   = Constant::MIN_SPLIT_QUANTITY
      max = (order_process.qty <= Constant::MAX_SPLIT_QUANTITY) ? (order_process.qty.to_i) : (Constant::MAX_SPLIT_QUANTITY + 1)
  
      until i==max
        options << [i, i]
        i += 1
      end
    else
      options << [order_process.split_by_val, order_process.split_by_val]  
    end

    if order_process.parent_order_id.nil?
      split_qty = "split_qty"
    else
      split_qty = ""
    end
    
    html = select_tag "split_by[]", options_for_select(options, [order_process.split_by_val, order_process.split_by_val]), 
            :class => "span1a #{split_qty} select-height",
            :id => order_process.id,
            :data_orig_value => order_process.split_by_val.to_s,
            :style => "font-size: 11px !important; height: 25px !important; width: 80px !important;"
    html
  end
  
  # to be deprecated
  def get_suppliers_for_select(order_processing)
    #suppliers = order_processing.get_suppliers(order_processing.product_id, session[:site_id])
    suppliers = OrderProcessing.get_suppliers(order_processing, session[:site_id])

    options = []
    suppliers.each do |supp|
      options << [supp.company_name, supp.id]
    end
    
    options
  end  
  
  def show_payment_image(order)
    if order.orderpaymentmethod.to_s.include?('VISA')
      return image_tag("https://www.petkusuri.com/images/payvisa.gif", :height => 15)
    elsif order.orderpaymentmethod.to_s.include?('JCB')
      return image_tag("https://www.petkusuri.com/images/payvisa.gif", :height => 15)
    elsif order.orderpaymentmethod.to_s.include?('MC')
      return image_tag("https://www.petkusuri.com/images/payvisa.gif", :height => 15)
    elsif order.orderpaymentmethod.to_s.include?("Bank Deposit")
      return image_tag("https://www.genkipet.com/images/payebank.gif", :height => 15)
    else
      return raw(order.orderpaymentmethod)
    end
  end
end
