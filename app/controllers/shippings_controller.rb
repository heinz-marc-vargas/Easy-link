#encoding: utf-8
class ShippingsController < ApplicationController
  before_filter :authenticate_user!
  before_filter :set_current_site

  def index
    @site_id = params[:site_id].present? ? params[:site_id] : session[:site_id]
    @site_id = current_user.sites.first.id if @site_id.nil?
    
    sent_params = params[:type].to_s == "sent" ? params : {}
    unsent_params = params[:type].to_s == "unsent" ? params : {}
    @mails = MailNotification.sent_mails(@site_id, sent_params)
    @unsent_mails = MailNotification.unsent_mails(@site_id, unsent_params)
    IscOrder.reconfigure_db(@site_id)
    
    respond_to do |format|
      format.js
    end
  end
  
  def show_logs
    @isd = IscShipmentData.find(params[:isd]) rescue nil
    @logs = []

    unless @isd.nil? 
      @logs = MailNotification.includes(:site).where("filename = ?", @isd.file_name)
    end
  end
  
  def notifications
    @isds = IscShipmentData.where("created_at >= ?", Time.current.to_date).order("created_at DESC")
    @mail_noti_count = MailNotification.where("created_at >= ?", Time.current.to_date).group("filename").count
    @isds_grouped = @isds.group_by(&:file_name)
  end

end
