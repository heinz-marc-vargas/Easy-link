class AddNewIndexesToMailNotifications < ActiveRecord::Migration
  def self.up
    add_index :mail_notifications, :token
  end

  def self.down
  end
end
