class AccountsController < ApplicationController
  before_filter :authenticate_user!
  
  def list_sales_invoice
    @generated_yr_mth = (params[:yr_month] == nil)? Time.now : Date.strptime(params[:yr_month], "%Y-%m")
    mths = [(@generated_yr_mth - 1.month).strftime('%Y-%m'), (@generated_yr_mth - 2.month).strftime('%Y-%m'), (@generated_yr_mth - 3.month).strftime('%Y-%m')]
    live_sites = Site.where("sitename LIKE '%LIVE%' AND sitename NOT LIKE '%Offline%'")  # production, all live sites
    @files = {}
    @available_generated_yr_mths = []
    
    live_sites.each do |site|
      @files[site.sitecode] = {}
      files = Dir.glob('data/accting/sales_invoice/' + site.sitecode + '/*')
      files.each do |f|
        @available_generated_yr_mths << f.split("gen-")[1].split("-")[0..1].join("-")
        if (@files[site.sitecode][f.split("gen-")[1].split("-")[0..1].join("-")] == nil)
          @files[site.sitecode][f.split("gen-")[1].split("-")[0..1].join("-")] = [f]
        else
          @files[site.sitecode][f.split("gen-")[1].split("-")[0..1].join("-")] << f
        end
      end
    end
    
    @available_generated_yr_mths = @available_generated_yr_mths.uniq
    
    respond_to do |format|
      format.html
      format.js
    end
  end
  
  def download_generated_xls
    unless (params[:filename].nil?)
      filepath = Rails.root.join('data', 'accting', 'sales_invoice', params[:sitecode], params[:filename])
      send_file filepath, :type => 'application/vnd.ms-excel', :disposition => 'attachment'
    else
      render :text => "File not available for download..."
    end
  end
  
  def list_unmatched_payments
    IscOrder.reconfigure_db(16)
    session[:show_all_unmatched_payments] = params[:show_all] rescue ((session[:show_all_unmatched_payments] != nil)? session[:show_all_unmatched_payments] : "n")
    
    unless params[:notes].nil?
      save_notes(params[:pmid].to_i, params[:notes])
    end
    
    sdate = "2012-10-01".to_date
    @available_yr_mths = []
    until (sdate.year >= Time.current.year && sdate.month > Time.current.month) 
      @available_yr_mths << sdate.year.to_s + "-" + sdate.month.to_s
      sdate += 1.month
    end
    @date = (params[:yr_month] != nil)? (params[:yr_month] + "-01") : (Time.current.year.to_s + "-" + Time.current.month.to_s + "-01")
    successful_payments = SmGcTransaction.where("response_order_status LIKE '%<RESPONSE><RESULT>OK</RESULT>%<STATUSID>800</STATUSID>%' AND date_time >= '" + @date + "' AND date_time < '" + (@date.to_date + 1.month).to_s + "'" + ((session[:show_all_unmatched_payments] != "y")? (" AND is_visible IS true") : "") )
    original_spm_oids = successful_payments.collect { |spm| spm.order_id }
    spm_oids = successful_payments.collect { |spm| spm.order_id.rjust(8,'9') }
    
    i = 0
    unmatched_oids = []
    IscOrder.reconfigure_db(17)
    until (i >= spm_oids.count)
      ord = IscOrder.where("orderid = " + spm_oids[i] + " AND ordstatus IN (11,9,3,2,10)")
      if (ord.empty?)
        unmatched_oids << original_spm_oids[i]
      end
      i += 1
    end
    
    IscOrder.reconfigure_db(16)
    @unmatched_payments = successful_payments.select { |pm| unmatched_oids.include?(pm.order_id) }
  end
  
  def save_mark_as_paid
    mssg = "Fail"
    
    begin
      raise "Fail - No order id" if params[:oid].blank?

      oid = params[:oid].to_i
      IscOrder.reconfigure_db(17)
      ord = IscOrder.find(oid.to_s.rjust(8, '9').to_i) rescue nil
      raise "Fail - Order not Found." if ord.nil?      

      if ![ Constant::ORDER_SUBMITTED, Constant::ORDER_PARTIALLY_SUBMITTED, Constant::ORDER_SHIPPED ].include? ord.ordstatus
        ord.ordstatus = 11
        
        if ord.save
          IscOrder.reconfigure_db(16)
          sm_gc_trxn = SmGcTransaction.find(params[:sm_gc_trxn_id].to_i)
          sm_gc_trxn.order_id = oid
      
          mssg = sm_gc_trxn.save ? "Success" : "Fail - Trxn not saved."
        else
          mssg = "Fail - Status not set."
        end
      end
    rescue Exception => e
      mssg = e.message
    end
    
    render :text => mssg
  end
  
  def save_visibility
    IscOrder.reconfigure_db(16)    
    payment = SmGcTransaction.find(params[:pmid].to_i)
    payment.is_visible = !(params[:invisibility] == "true")
    
    render :text => (payment.save!)? "Saved" : "Not saved"
  end
  
  def save_notes (pmid, notes)
    payment = SmGcTransaction.find(pmid)
    payment.notes = notes
    
    return (payment.save!)? "Saved" : "Not saved"
  end
  
  def list_sale_totals
    # Calculate & list totals for all paid, submitted, partially shipped, & shipped orders.
    # Limit by number of days / month? Calculated based on paid, date, not order date as customers may not pay until weeks later.
    sdate = "2012-10-01".to_date
    @available_yr_mths = []
    until (sdate.year >= Time.current.year && sdate.month > Time.current.month) 
      @available_yr_mths << sdate.year.to_s + "-" + sdate.month.to_s
      sdate += 1.month
    end
    @date = (params[:yr_month] != nil)? (params[:yr_month] + "-01") : Time.current.strftime("%Y-%m-01")
    @bank_trxn_payment_total = BankTransaction.get_total_ws_bt_payments_collected(@date)
    trxns_amts_total = SmGcTransaction.get_total_payments_collected(@date)
    @ccsm_trxns = trxns_amts_total[0]
    @amts = trxns_amts_total[1]
    @ccsm_payment_total = trxns_amts_total[2]
    
    @payment_total = @bank_trxn_payment_total + @ccsm_payment_total
  end
end
