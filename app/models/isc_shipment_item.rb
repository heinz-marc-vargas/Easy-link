class IscShipmentItem < ActiveRecord::Base
  set_primary_key "itemid"
  has_one :isc_shipments, :foreign_key => "shipid"
  
  simple_audit do |isi_record|
    {
        :itemid => isi_record.itemid,
        :shipid => isi_record.shipid,
        :itemprodid => isi_record.itemprodid,
        :itemordprodid => isi_record.itemordprodid,
        :itemprodsku => isi_record.itemprodsku,
        :itemprodname => isi_record.itemprodname,
        :itemqty => isi_record.itemqty,
        :itemprodoptions => isi_record.itemprodoptions,
        :itemprodvariationid => isi_record.itemprodvariationid,
        :itemprodeventname => isi_record.itemprodeventname,
        :itemprodeventdate => isi_record.itemprodeventdate,
        :site_id => (Site.current_site.id rescue nil),
        :username_method => User.current
    }
  end
  
  class << self
    
    def create_shipment_items(order_id, ship_id)
      return nil if order_id.nil? || ship_id.nil?
      order_products = IscOrderProduct.where("orderorderid = ?", order_id)
      return nil if order_products.nil?
      saved = []
      
      order_products.each do |op|
        existing_items = IscShipmentItem.where("itemprodid = ? AND shipid = ?", op.ordprodid, ship_id)

        if existing_items.empty?
          ship_item = IscShipmentItem.new(
            :shipid => ship_id,
            :itemprodid => op.ordprodid,
            :itemordprodid => op.orderprodid, 
            :itemprodsku => op.ordprodsku,
            :itemprodname => op.ordprodname, 
            :itemqty => op.ordprodqty, 
            :itemprodoptions => op.ordprodoptions,
            :itemprodvariationid => op.ordprodvariationid, 
            :itemprodeventname => op.ordprodeventname,
            :itemprodeventdate => op.ordprodeventdate )
          
          if ship_item.save
            saved << ship_item
          else
            Rails.logger.info("ERROR: IscShipmentItem.create_shipment_items(#{order_id}, #{ship_id}), IscOrderProduct.orderprodid: #{op.orderprodid}")
          end
        end
      end
    end
    
  end
end
