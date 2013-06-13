#encoding: utf-8
module Helpers
 
  def self.get_scr_expiry(site_id)
    site = Site.find(site_id)

    val = case site.sitecode.to_s
      when "BK"
        Constant::BK_EXPIRY_DAYS
      when "KX"
        Constant::KK_EXPIRY_DAYS
      when "PK"
        Constant::PK_EXPIRY_DAYS
      when "GP"
        Constant::GP_EXPIRY_DAYS
    end

    val
  end
 
  def self.clean_sava_field(string=nil)
    return '' if string.nil?
    string.gsub!(/['~"]/,'')
    string
  end
  
  def self.convert_multi_to_single_byte_alpha_num(str = "")
    str = str.gsub(/[〜－]/, "-")
    str = self.remove_illegal_chars(str)

    return ActiveSupport::Multibyte::Chars.new(str).normalize(:kc)
  end

  def self.remove_illegal_chars(str = "")
    str = str.gsub(/~/, "-")
    return str
  end

  def self.mage_to_isc_ordstatus(mage_status)
    status = case mage_status.to_s
      when "processing"
        11
      when "submitted"
        9
      when "partially_shipped"
        3
      when "complete"
        2
      when "canceled"
        4
      when "pending", "pending_payment"
        1
      else
        7  
      end

    status
  end

  def self.isc_to_mage_ordstatus(ordstatus)
    status = case ordstatus.to_i
        when 11
          "processing"
        when 9
          "submitted"
        when 3
          "partially_shipped"
        when 2
          "complete"
        when 4
          "canceled"
        when 7, 1
          "pending"
        else
          "pending"
        end
    status
  end

  def self.get_status_id(status_str)
    status = case status_str.to_s
    when "pending"
      Constant::ORDER_PENDING
    when "unpaid"
      Constant::ORDER_UNPAID
    when "paid"
      Constant::ORDER_PAID
    when "submitted"
      Constant::ORDER_SUBMITTED
    when "partially-shipped"
      Constant::ORDER_PARTIALLY_SUBMITTED
    when "shipped"
      Constant::ORDER_SHIPPED
    when "cancelled"
      Constant::ORDER_CANCELLED
    else
      Constant::ORDER_PENDING
    end
    
    status
  end
    
  def self.get_site_id(order_id)
    if order_id.to_s.length <= 8
      case order_id.to_s.first
      when "2"
        return Site.find_by_sitecode("BK").id
      when "3"
        return Site.find_by_sitecode("PK").id
      when "4"
        return Site.find_by_sitecode("GP").id
      when "6"
        return Site.find_by_sitecode("HB").id
      when "7"
        return Site.find_by_sitecode("777").id
      when "8"
        return Site.find_by_sitecode("KX").id
      when "9"
        return Site.find_by_sitecode("WSH").id
      else
        return nil
      end    
    else
      return Site.find_by_sitecode("PKY").id
    end
  end
  
  def self.clean_payment_string(str)
    str = str.gsub("(VIS","")
    str = str.gsub("A,MC,","")
    str = str.gsub("(VIS","")
    str = str.split("JCB").first.to_s
    str = str.gsub("storecredit", "ストアポイント")
    str = str.gsub("(ご利用可能: Visa/Master/", "")
    return str.to_s    
  end
  
end
