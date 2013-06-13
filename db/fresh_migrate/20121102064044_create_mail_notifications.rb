class CreateMailNotifications < ActiveRecord::Migration
  def self.up
    create_table :mail_notifications do |t|
      t.integer :order_id
      t.integer :site_id
      t.string  :email
      t.string  :log
      t.integer :mailable_id
      t.string  :mailable_type
      t.boolean :sent, :default => false
      t.string  :filename

      t.timestamps
    end
  end

  def self.down
  end
end
