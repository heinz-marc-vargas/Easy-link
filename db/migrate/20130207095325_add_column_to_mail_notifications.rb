class AddColumnToMailNotifications < ActiveRecord::Migration
  def self.up
    add_column :mail_notifications, :token, :string, :null => true
    add_column :mail_notifications, :notes, :text, :null => true
  end

  def self.down
    remove_column :mail_notifications, :notes
    remove_column :mail_notifications, :token
  end
end
