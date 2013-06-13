class CreateSuppliers < ActiveRecord::Migration
  def self.up
    create_table :suppliers do |t|
      t.string :name
      t.integer :status
      t.timestamps
    end
  end

  def self.down
    
  end
end
