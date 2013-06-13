class CreateCounters < ActiveRecord::Migration
  def self.up
    create_table :counters do |t|
      t.integer :paid_orders
      t.integer :submitted_orders
      t.integer :shipped_orders
      t.integer :site_id

      t.timestamps
    end
  end

  def self.down
    drop_table :counters
  end
end
