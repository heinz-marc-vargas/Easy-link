class CreateCacheFragments < ActiveRecord::Migration
  def self.up
    create_table :cache_fragments do |t|
      t.string :name
      t.integer :site_id
      t.boolean :status, :default => false

      t.timestamps
    end

    add_index :cache_fragments, :name
    add_index :cache_fragments, :site_id
    add_index :cache_fragments, :status

  end

  def self.down
    drop_table :cache_fragments
  end
end
