class CreateBanks < ActiveRecord::Migration
  def self.up
    create_table :banks do |t|
      t.string :bank_name
      t.integer :site_id

      t.timestamps
    end
  end

  def self.down
    drop_table :banks
  end
end
