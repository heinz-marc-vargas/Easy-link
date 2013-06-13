class CreateWebsharkFiles < ActiveRecord::Migration
  def self.up
    create_table :webshark_files do |t|
      t.string :filename
      t.integer :downloader_id
      t.string :downloader_type
      t.string :status
      t.text :logs
      t.text :extras
      t.integer :site_id
      t.integer :deleted_by
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :webshark_files, [:downloader_id, :downloader_type]
    add_index :webshark_files, :filename
    add_index :webshark_files, :status
    add_index :webshark_files, :site_id
    add_index :webshark_files, :deleted_by
    add_index :webshark_files, :deleted_at
  end

  def self.down
    drop_table :webshark_files
  end
end
