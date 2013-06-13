#encoding: utf-8
class BankTransactionsController < ApplicationController
  before_filter :authenticate_user!, :except => [:show_comment_form]
  before_filter :set_current_site

  def set_orderid
    @bt = BankTransaction.find(params[:btid]) rescue nil    
    @bt.set_orderid(params[:order_id]) unless @bt.nil?
  end
  
  def export_download
    begin
      file = Rails.root.join("data", "bank_trxns", params[:file])
      send_file file.to_s, :type => 'application/vnd.ms-excel', :disposition => 'attachment', :x_sendfile => true
    rescue Exception => e
      render :text => "Error: #{e.message}"
    end    
  end
  
  def export
    begin
      csv_data = BankTransaction.get_data_to_export(params[:yr_month], params[:bank_id])
      file_name = BankTransaction.create_csv(csv_data, params[:bank_id], params[:yr_month])
      
      render :json => { :filename => file_name }
    rescue Exception => e
      Rails.logger.info("#{e.message}")
      render :json => { :errormsg => "Error: #{e.message}" }
    end
  end

  def import_payment
    require 'csv'
    @error_message = nil
    site_ids = current_user.sites.map(&:id)
    @banks_select = Bank.where("site_id IN (?)", site_ids).collect{|b| ["#{b.bank_name} | #{b.site.sitename}", b.id] }
    bank = Bank.find(params[:bank_id]) rescue nil
    session[:site_id] = bank.site_id unless bank.nil?
    @payment_amt_details = []
    
    if request.post?
      begin
        result = BankTransaction.import_payment(params[:bank_id], params[:file])
        @payment_amt_details = result[:payment_amt_details]
        @possible_order_ids  = result[:possible_order_ids]
        @possible_first_last_names = result[:possible_first_last_names]
        @possible_orders     = result[:possible_orders]
        @status_updated      = result[:status_updated]
      rescue Exception => e        
        @error_message = "Error: #{e.message}"
      end
    end        
  end

  def update_sales_channel
    begin
      channel_id = nil
      channel_id = params[:channel_id] unless params[:channel_id].blank?
      @trxn = BankTransaction.find(params[:id]) rescue nil
      @trxn.update_attribute(:other_sales_channel_id, channel_id) unless @trxn.nil?

      respond_to do |format|
        format.js
      end
    rescue Exception => e
      Rails.logger.info("\n\nError: #{e.message}")
    end
  end
  
  #deprecated
  def edit_transaction_details_for_deletion
    transaction_id = params[:tid].to_i
    @transaction = BankTransaction.find(transaction_id)
    @site_name = Site.find(@transaction.site_id).sitename
    @bank_name = Bank.find(@transaction.bank_id).bank_name
    @possible_orders = nil
    @external_sales_channels = ExternalSalesChannels.find(:all)
  end

  #deprecated
  def save_changes_for_deletion
    begin
      bank_trxn = BankTransaction.find(params[:bank_transactions][:trxn_id].to_i)
      bank_trxn.staff_comments = params[:bank_transactions][:staff_comments]
      bank_trxn.other_sales_channel_id = (params[:sales_channel] == "" || params[:sales_channel] == nil)? nil : params[:sales_channel].to_i
    
      if (params[:bank_transactions][:order_ids] != bank_trxn.order_ids)
        # Note: In the case of removed order_ids, they need to determine the correct order status themselves 7 set it to the correct status
        oids = params[:bank_transactions][:order_ids].gsub(/ /, "").split(",").uniq
        logger.info("OIDS: " + oids.inspect + "bank_trxns: " + bank_trxn.inspect)
        bank_trxn_oids = (bank_trxn.order_ids == nil)? [] : bank_trxn.order_ids.split(",")
        unique_oids = oids - bank_trxn_oids
        #bank_trxn.order_ids = (params[:bank_transactions][:order_ids].gsub(/ /, "").split(",").uniq.join(","))
        bank_trxn.order_ids = oids.join(",")
      
        if (unique_oids != [])
          IscOrder.reconfigure_db(params[:bank_transactions][:site_id].to_i)
          ords = IscOrder.find_by_sql("SELECT * FROM isc_orders WHERE orderid IN (" + unique_oids.join(",") + ")")
          #oids.each do |oid|
          #  ord = IscOrder.find(oid)
          ords.each do |ord|
              if (ord.ordstatus == 1 || ord.ordstatus == 7 || ord.ordstatus == 8)   # Pending / unpaid. Production
                ord.markAsPaid(params[:bank_transactions][:site_id].to_i)  # mark as paid & send notification
                  bank_trxn.status_change_date = Time.now.strftime("%Y-%m-%d_%H-%M-%S")
              end
          end
        end
      end
    
      if bank_trxn.save
        render :text => "Changes Saved"
      else
        raise "Changes not saved. Please check the data."
      end
    rescue Exception => e
      Rails.logger.info("Error: #{e.message}")
    end
  end

  def index
    yr_month = params[:yr_month] || "#{Time.now.year}-#{Time.now.month}"
    bank = Bank.find(params[:bank_id]) rescue nil
    session[:site_id] = bank.site_id unless bank.nil?
    session[:site_code] = bank.site.sitecode unless bank.nil?

    IscOrder.reconfigure_db(session[:site_id])
    site_ids = current_user.sites.map(&:id)
    @transactions = []    
   
    @transactions = BankTransaction.get_transactions(yr_month, bank.id, bank.site_id, {:page => params[:page], :perpage => params[:per_page]}) unless bank.nil?
    @yr_month_select = BankTransaction.by_year_month
    @banks_select = Bank.where("site_id IN (?)", site_ids).collect{|b| ["#{b.bank_name} | #{b.site.sitename}", b.id] }
    @external_sales_channels =  ExternalSalesChannels.find(:all)
    
    order_ids = @transactions.map(&:order_ids).uniq.compact
    @orders = IscOrder.where("orderid IN (?)", order_ids).group_by(&:orderid)

    respond_to do |format|
      format.html
      format.js
    end
  end
  
  def set_sequence
    params[:sequence_id].each do |trxn_id, val|
      trxn = BankTransaction.find(trxn_id)
      unless trxn.nil?
        trxn.sequence_id = val.to_i
        esc_id = params[:sales_channel]["#{trxn_id}"].to_i rescue 0
        trxn.other_sales_channel_id = esc_id if esc_id > 0
        trxn.save
      end
    end    
    
    respond_to do |format|
      format.html
      format.js
    end    
  end

  def convert_multi_to_single_byte_alpha_num(str = "")
    str = str.gsub(/〜/, "-")
    str = str.gsub(/－/, "-")
    str = remove_illegal_chars(str)

    return ActiveSupport::Multibyte::Chars.new(str).normalize(:kc)
  end
  
  def remove_illegal_chars(str = "")
   str = str.gsub(/~/, "-")

   return str
  end
end


