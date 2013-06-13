class AddLastSentAtToTableMailNotification < ActiveRecord::Migration
  def self.up
    add_column :mail_notifications, :last_sent_at, :datetime
  end

  def self.down
  end
end
