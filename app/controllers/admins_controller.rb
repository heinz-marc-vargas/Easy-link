#encoding: utf-8
class AdminsController < ApplicationController
  before_filter :authenticate_user!

  def processings
    date_start =  2.weeks.ago.to_date    
    order_ids   = OrderProcessing.where("order_id > 0 AND DATE_FORMAT(created_at, '%Y-%m-%d') >= ? ", date_start.strftime("%Y-%m-%d")).order("created_at DESC, orderprodid DESC").map(&:order_id)
    ops         = OrderProcessing.where("order_id IN (?)", order_ids)
    ops_grouped = ops.group_by(&:order_id)

    @dups_array = {}
    ops_grouped.keys.each do |order_id|
      tmp  = []

      ops_grouped[order_id].each do |op|
        tmp << "#{op.order_id}-#{op.orderprodid}-#{op.product_id}-#{op.site_id}"
      end

      ans = tmp.uniq!
      @dups_array[order_id] = ops_grouped[order_id] if ans.is_a? Array
    end
    
    respond_to do |format|
      format.js
      format.html
    end
  end
  
  def notes
    page    = params[:page].blank? ? 1 : params[:page]
    perpage = params[:per_page].blank? ? Constant::PERPAGE : params[:per_page]
    @notes  = Note.order("created_at DESC").page(page).per_page(perpage)
  end
  
  def create_note
    Note.create(params[:note])
  end
  
  def pendingjobs
    page    = params[:page].blank? ? 1 : params[:page]
    perpage = params[:per_page].blank? ? Constant::PERPAGE : params[:per_page]
    @jobs   = Job.order("created_at DESC").page(page).per_page(perpage)
  end
  
  def deletejob
    @job = Job.find(params[:id])
    @job.destroy
  end
end
