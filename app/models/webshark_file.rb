class WebsharkFile < ActiveRecord::Base
  belongs_to :downloader, :polymorphic => true
  belongs_to :site  

  class << self
    
    def create_new(options)
      user = User.find(options[:user_id]) rescue nil
      wfile = WebsharkFile.new
      wfile.filename = options[:filename]
      wfile.status = "Not processed"
      wfile.site_id = options[:site_id] unless options[:site_id].nil?
      wfile.downloader_id = user.id unless user.nil?
      wfile.downloader_type = "User" unless user.nil?
      
      return wfile if wfile.save
      nil
    end
  end
end
