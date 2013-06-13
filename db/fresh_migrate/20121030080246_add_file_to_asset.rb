class AddFileToAsset < ActiveRecord::Migration
  def self.up
    add_column :assets, :file_file_name,    :string
    add_column :assets, :file_content_type, :string
    add_column :assets, :file_file_size,    :integer
    add_column :assets, :file_updated_at,   :datetime
  end

  def self.down
  end
end
