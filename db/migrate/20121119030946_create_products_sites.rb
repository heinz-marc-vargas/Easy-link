class CreateProductsSites < ActiveRecord::Migration
  def self.up
    create_table :products_sites, :id => false do |t|
      t.integer :site_id
      t.integer :product_id
    end
  end

  def self.down
    
  end
end
