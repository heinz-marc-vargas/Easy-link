class MailNotification < ActiveRecord::Base
  belongs_to :mailable, :polymorphic => true
  belongs_to :site, :foreign_key => "site_id"
  belongs_to :isc_order, :foreign_key => "order_id"

  #after_create :update_last_sent  
  serialize :notes

  self.per_page = 15
  
  class << self
    def create_log(cols = {})
      mn = MailNotification.create(cols)
      return mn
    end
    
    def unsent_mails(site_id, args = {})
      page = 1
      page = args[:page] if args[:page].present?
      search_str = args[:q].present? ? args[:q] : nil
      
      unless search_str.nil?
        where("site_id = ? AND token IS NOT NULL AND sent_at IS NULL AND order_id like ?", site_id, "%#{search_str}%").order("created_at DESC").page(page)
      else
        where("site_id = ? AND sent_at IS NULL AND token IS NOT NULL", site_id).order("created_at DESC").page(page)
      end
      
    end
    
    def sent_mails(site_id, args={})
      page = 1
      page = args[:page] if args[:page].present?
      search_str = args[:q].present? ? args[:q] : nil

      unless search_str.nil?
        where("site_id = ? AND sent_at IS NOT NULL AND token IS NOT NULL AND order_id like ?", site_id, "%#{search_str}%").order("created_at DESC").page(page)
      else
        where("site_id = ? AND sent_at IS NOT NULL AND token IS NOT NULL", site_id).order("created_at DESC").page(page)
      end 
    end
  end

  def update_last_sent
    #self.update_attribute(:last_sent_at, Time.current)
  end  
end
