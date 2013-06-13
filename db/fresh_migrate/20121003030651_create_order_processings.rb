class CreateOrderProcessings < ActiveRecord::Migration
  def self.up
    create_table :order_processings do |t|
      t.integer :order_id
      t.integer :sent

      t.timestamps
    end
  end

  def self.down
    drop_table :order_processings
  end
end
