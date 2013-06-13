class AddAssetIdToOrdersToSuppliers < ActiveRecord::Migration
  def self.up
    add_column :orders_to_suppliers, :asset_id, :integer
  end

  def self.down
  end
end
