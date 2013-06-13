class CreateIscProducts < ActiveRecord::Migration
  def self.up
    create_table :isc_products do |t|
      t.integer :product_id
      t.integer :consume_days
      t.string  :prodname
      t.integer :prodtype
      t.string  :prodcode
      t.string  :prodfile
      t.text    :proddesc
      t.text    :prodsearchkeywords
      t.string  :prodavailability
      t.float   :prodprice, :precision => 20, :scale => 4
      t.decimal :prodcostprice, :precision => 20, :scale => 4
      t.decimal :prodretailprice, :precision => 20, :scale => 4
      t.decimal :prodsaleprice, :precision => 20, :scale => 4
      t.decimal :prodcalculatedprice, :precision => 20, :scale => 4
      t.boolean :prodistaxable
      t.integer :prodsortorder
      t.integer :prodvisible 
      t.integer :prodfeatured
      t.boolean :prodvendorfeatured
      t.string  :prodrelatedproducts
      t.integer :prodcurrentinv
      t.integer :prodlowinv
      t.integer :prodoptionsrequired
      t.text    :prodwarranty
      t.decimal :prodweight, :precision => 20, :scale => 4
      t.decimal :prodwidth, :precision => 20, :scale => 4
      t.decimal :prodheight, :precision => 20, :scale => 4
      t.decimal :proddepth, :precision => 20, :scale => 4
      t.decimal :prodfixedshippingcost, :precision => 20, :scale => 4
      t.integer :prodfreeshipping, :precision => 20, :scale => 4

      t.timestamps
    end

    add_index :isc_products, :product_id
  end

  def self.down
    
  end
end
