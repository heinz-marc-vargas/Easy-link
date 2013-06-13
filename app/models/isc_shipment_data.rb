class IscShipmentData < ActiveRecord::Base
  set_table_name "isc_shipment_data"
  belongs_to :isc_order
 
  validates :order_id, :presence => true
  validates :ext_product_id, :presence => true
  validates :tracking_num, :presence => true
  validates :qty_shipped, :presence => true
  validates :file_name, :presence => true

  attr_accessor :is_new
    
  simple_audit do |isd_record|
    {
        :id => isd_record.id,
        :order_id => isd_record.order_id,
        :ship_flag => isd_record.ship_flag,
        :ext_product_id => isd_record.ext_product_id,
        :qty_shipped => isd_record.qty_shipped,
        :tracking_num => isd_record.tracking_num,
        :ship_date => isd_record.ship_date,
        :file_name => isd_record.file_name,
        :site_id => (Site.current_site.id rescue nil),
        :username_method => User.current
    }
  end

  class << self
    def shipped_today
       isd = where("DATE_FORMAT(ship_date, '%Y-%m-%d') = ?", Time.current.strftime("%Y-%m-%d"))
       order_ids = isd.map(&:order_id).uniq
       order_ids      
    end
    
    def latest(limit = 15)
      group("file_name").order("created_at DESC").limit(limit)
    end
    
    def insert_order(order_row)
      Rails.logger.info("Creating IscShipmentData.insert_order order_row: #{order_row.inspect}")
      ext_product_id = order_row[:ext_product_id].to_s.gsub(/-/, "_")
      order_row[:ext_product_id] = ext_product_id

      dup = where("order_id = ? AND ext_product_id = ? AND tracking_num = ?", 
            order_row[:order_id].to_i, ext_product_id, "#{order_row[:tracking_num]}")
      
      if dup.empty?
        isd = IscShipmentData.create(order_row)
        Rails.logger.info("Successfully created IscShipmentData: #{isd.inspect}")
        isd.is_new = true
        return isd
      else
        dup.each do |isd|
          isd.update_attribute(:ship_date, order_row[:ship_date]) unless order_row[:ship_date].nil?
        end

        Rails.logger.info("Duplicate record: #{order_row.inspect}")
        return dup.last.reload
      end
      
      return nil
    end
  end
  #end of class methods
  
  def is_new
    @is_new || false
  end
  
  def is_new=val
    @is_new=val
  end


  def get_shipment_results
    result = { :missing => [], :recorded => [] }
    filepath = Rails.root.join("data", "shipping_files", self.file_name)
    return result if !File.exists?(filepath)
    
    Spreadsheet.client_encoding = 'UTF-8'
    xls = Spreadsheet.open filepath
    sheet = xls.worksheet 0
    skip_rows = 1 

    fname_arr = self.file_name.split("_")
        
    if fname_arr.first == "WM" #westmead
      order_rows = XlsParser.get_order_rows(self.file_name, "westmead")
    elsif fname_arr.first == "SV" #sava
      order_rows = XlsParser.get_order_rows(self.file_name, "sava")
    else
      raise "This file / supplier is not yet supported."
    end
    
    order_rows.each do |row|
      Rails.logger.info("#{row.inspect}")
      ext_product_id = row[:ext_product_id].to_s.gsub(/-/, "_")

      isd = IscShipmentData.where("order_id = ? AND ext_product_id = ? AND tracking_num = ? AND qty_shipped = ?",
              row[:order_id], ext_product_id, row[:tracking_num], row[:qty_shipped])
      Rails.logger.info("isd=#{isd.length}")
      
      if isd.empty?
        result[:missing] << row
      else
        result[:recorded] << isd.first
      end
    end
    
    result
  end

  def get_item_id
    product = Product.where("ext_product_id=?", ext_product_id).first

    if product.uid > 0
      products = Product.where("uid=?", product.uid)
      products.each do |p|
        ops = OrderProcessing.where("order_id = ? AND product_id = ?", order_id, p.id) rescue []
        return ops.first.item_id unless ops.empty?
      end
    else
      ops = OrderProcessing.where("order_id = ? AND product_id = ?", order_id, product.id) rescue []
      return ops.first.item_id unless ops.empty?
    end

    nil
  end
end
