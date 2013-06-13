class AddDescriptionToSuppliers < ActiveRecord::Migration
  def self.up
    add_column :suppliers, :description, :string
  end

  def self.down
    remove_column :suppliers, :description
  end
end
