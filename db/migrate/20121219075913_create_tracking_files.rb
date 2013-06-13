class CreateTrackingFiles < ActiveRecord::Migration
  def self.up
    create_table :tracking_files do |t|
      t.string :filename
      t.integer :uploader_id
      t.string :uploader_type
      t.string :status
      t.text :logs

      t.timestamps
    end

    add_index :tracking_files, [:uploader_id, :uploader_type]
    add_index :tracking_files, :status
    add_index :tracking_files, :filename
  end

  def self.down
    drop_table :tracking_files
  end
end
