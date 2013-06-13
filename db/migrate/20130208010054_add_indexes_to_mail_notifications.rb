class AddIndexesToMailNotifications < ActiveRecord::Migration
  def self.up
    add_index :mail_notifications, :site_id
    add_index :mail_notifications, :order_id
    add_index :mail_notifications, :sent
    add_index :mail_notifications, :sent_at
  end

  def self.down
  end
end
