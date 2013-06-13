class SupplierProduct < ActiveRecord::Base
  has_one :supplier, :foreign_key => "id"
  belongs_to :supplier_product_map, :foreign_key => "supplier_product_id"
end
