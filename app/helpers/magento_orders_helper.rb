module MagentoOrdersHelper
  
  def get_oc_status(mage_status)
    status = case mage_status.to_s
    when "processing"
      "Paid"
    when "partially_shipped"
      "Partially Shipped"
    when "submitted"
      "Submitted"
    when "complete"
      "Shipped"
    when "canceled"
      "Canceled"
    when "pending"
      "Pending"
    when "pending_payment"
      "Unpaid"
    else
      "Unpaid"  
    end
    
    status
  end



end
