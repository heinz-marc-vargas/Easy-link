class AddColumnSentAtToMailNotifications < ActiveRecord::Migration
  def self.up
    add_column :mail_notifications, :sent_at, :datetime
  end

  def self.down
    remove_column :mail_notifications, :sent_at
  end
end
