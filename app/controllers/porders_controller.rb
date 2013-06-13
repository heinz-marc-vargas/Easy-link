#encoding: utf-8
class PordersController < ApplicationController
  before_filter :authenticate_user!
  before_filter :set_current_site
 
  def index
    @orders = []
    
    unless params[:q].blank?
      IscOrder.reconfigure_db(17)
      @statuses = IscOrderStatus.status_hash
      @orders = IscOrder.powacom_search(17, params)
    end
    
    respond_to do |format|
      format.js
    end
  end
end
