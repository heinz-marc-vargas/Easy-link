class CreateAssets < ActiveRecord::Migration
  def self.up
    create_table :assets do |t|
      t.string :name, :null => false
      t.integer :site_id, :null => false
      t.integer :asset_id
      t.string :asset_type
      t.text :order_ids
      t.integer :user_id

      t.timestamps
    end
  end

  def self.down
    drop_table :assets
  end
end
