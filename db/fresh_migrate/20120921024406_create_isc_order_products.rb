class CreateIscOrderProducts < ActiveRecord::Migration
  def self.up
    create_table :isc_order_products do |t|
      t.integer :orderprodid
      t.string :ordprodsku
      t.string :ordprodname
      t.integer :reminder_date
      t.string :ordprodtype
      t.decimal :base_price, :precision => 20, :scale => 4
      t.decimal :price_ex_tax, :precision => 20, :scale => 4
      t.decimal :price_inc_tax, :precision => 20, :scale => 4
      t.decimal :price_tax, :precision => 20, :scale => 4
      t.decimal :base_total, :precision => 20, :scale => 4
      t.decimal :total_ex_tax, :precision => 20, :scale => 4
      t.decimal :total_inc_tax, :precision => 20, :scale => 4
      t.decimal :total_tax, :precision => 20, :scale => 4
      t.decimal :ordprodweight, :precision => 20, :scale => 4
      t.integer :ordprodqty
      t.integer :orderorderid
      t.integer :ordprodid
      t.integer :ordprodid
      t.decimal :base_cost_price, :precision => 20, :scale => 4
      t.decimal :cost_price_ex_tax, :precision => 20, :scale => 4
      t.decimal :cost_price_inc_tax, :precision => 20, :scale => 4
      t.decimal :cost_price_tax, :precision => 20, :scale => 4
      t.decimal :ordoriginalprice, :precision => 20, :scale => 4
      t.integer :ordprodrefunded
      t.decimal :ordprodrefundamount, :precision => 20, :scale => 4
      t.integer :ordprodreturnid
      t.text :ordprodoptions
      t.integer :ordprodvariationid
      t.integer :ordprodwrapid
      t.string :ordprodwrapname
      t.decimal :base_wrapping_cost, :precision => 20, :scale => 4
      t.timestamps
    end

    add_index :isc_order_products, :orderprodid
  end

  def self.down
    
  end
end
