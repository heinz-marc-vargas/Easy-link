class CreateEmails < ActiveRecord::Migration
  def self.up
    create_table :emails do |t|
      t.integer "user_id"
      t.string "to"
      t.string "from"
      t.string "cc"
      t.string "subject"
      t.string "content"
      t.string "attachments"
      t.integer "supplier_id"
      t.boolean "sent",       :default => 0
      t.timestamps
    end
  end

  def self.down
    #drop_table :emails
  end
end
