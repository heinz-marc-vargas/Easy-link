class CreateSites < ActiveRecord::Migration
  def self.up
    create_table :sites do |t|
      t.string :name
      t.string :sitecode
      t.string :site_url
      t.string :hostname
      t.string :dbname
      t.string :dbuser
      t.string :dbpass

      t.timestamps
    end

  end

  def self.down
    
  end
end
