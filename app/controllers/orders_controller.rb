#encoding: utf-8
class OrdersController < ApplicationController
  before_filter :authenticate_user!, :except => [ :update_totals ]
  before_filter :set_current_site
  
  def undelete
    begin
      IscOrder.reconfigure_db(params[:site_id])
      @order = IscOrder.where("orderid = ? AND ordstatus=0", params[:id]).first
      @order.undelete(params[:status], params[:notes]) unless @order.nil?
    rescue Exception => e
      Rails.logger.info("Error: #{e.message}")
    end
  end
  
  def setnotes
    IscOrder.reconfigure_db(params[:site_id])
    @order = IscOrder.find(params[:id])
    @order.setnotes(params[:order_notes]) unless @order.nil?
  end

  #deprecated
  def dlwebshark_for_deletion
    ws = WebsharkFile.find(params[:id])

    unless ws.nil?
      if params[:ftype].to_s == "products"
        fname = ws.filename.to_s.gsub("orders", "orders_products")
        filepath = Rails.root.join('data', 'ws_order_data', fname)
      else
        filepath = Rails.root.join('data', 'ws_order_data', ws.filename)        
      end
      
      send_file filepath, :type => 'text/csv', :disposition => 'attachment'
    else
      render :text => "Sorry, file does not exist!"
    end
  end
  
  def change_supplier
    expire_fragment("#{session[:site_id]}-preview_supplier_order_data")

    @op = OrderProcessing.find(params[:op_id]) rescue nil
    @op.change_supplier(params[:supplier_id]) unless @op.nil?
        
    respond_to do |format|
      format.js
    end    
  end
  
  def mark_order_as_paid
    expire_fragment("#{session[:site_id]}-preview_supplier_order_data")
    
    begin
      order_id  = params[:order_id].to_i
      site_id   = session[:site_id].to_i
      bt = BankTransaction.mark_as_paid(params[:btid], order_id, site_id)
      raise "Mark order as paid failed" if bt.nil?
      render :text => t(:mark_as_paid)  and return
    rescue Exception => e
      render :text => "Error: #{e.message}" and return
    end
  end
  
  def send_reorders
    expire_fragment("#{session[:site_id]}-preview_supplier_order_data")
    otss = OrdersToSupplier.reorder_ots(params, session[:site_id], session[:test_mode])
    OrderSender.prepare_reorder(otss)
    @otss_created = otss

    respond_to do |format|
      format.js
    end
  end

  def reorders
    @sites = current_user.sites_for_select
    IscOrder.reconfigure_db(@site.id)
    order_ids, @orders = [], []

    unless params[:order_ids].nil?
      order_ids = params[:order_ids].split(",")
      order_ids.collect!{ |id| id.to_s.strip.to_i }
    end
    page = params[:page] || 1

    @split_by_values = ["--"]
    for i in 10..20
      @split_by_values << i
    end
    
    unless order_ids.empty?
      @orders = IscOrder.includes(:order_processings, :isc_order_address, :isc_order_shipping).
               where("orderid IN (?)", order_ids).
               order("orderid DESC").
               page(page).
               per_page(20)
    end
  end

  def imports
    @errors   = nil
    @success  = false
    @tracking = nil

    if request.post?
      begin
        file = params[:isc_shipment_data][:file_name]
        filename = params[:isc_shipment_data][:file_name].original_filename
        raise "Invalid file format" if !Constant::XLS_CONTENT_TYPES.include?(file.content_type.to_s)
        
        dup = IscShipmentData.where("file_name=?", filename)
        raise "Filename already exists." unless dup.empty?

        fpath = Rails.root.join(Constant::DIR_SF)
        FileUtils.mkdir_p(fpath) unless File.exists? fpath
        raise "Filename already exists." if File.exists?(Rails.root.join(Constant::DIR_SF, filename))

        File.open(Rails.root.join(Constant::DIR_SF, filename), 'wb') do |f|
          f.write(file.read)
        end
        
        @tracking = TrackingFile.new(:filename => filename, :uploader => current_user, :status => TrackingFile::STATUS[:pending])
        TrackingFile.delay(:queue => Constant::Q_OTHERS).process_file(@tracking.id) if @tracking.save
      rescue Exception => e
        @errors = "Error: #{e.message}"
      end    
    end
    
    @shipment_files = IscShipmentData.latest(15)
    @pending_tracking_files = TrackingFile.where("status IN (?)", TrackingFile::STATUS.values.join(",")).order("created_at DESC").limit(50)

    @pending_tracking_files.each do |tf|
      tf.processed_counter = IscShipmentData.where("file_name=?", tf.filename.to_s).count
    end
    
  end
  
  def generate_spreadsheet
    XlsParser.generate_xls(params[:site_id], params[:date])
  end

  def check_shipping_xls
     @isd = IscShipmentData.find(params[:isd]) rescue nil
     @missing, @recorded = [], []

     if @isd.nil?
       render :text => "Error: Invalid ID"
     else
       shipment_results = @isd.get_shipment_results
       @missing = shipment_results[:missing]
       @recorded = shipment_results[:recorded]
     
       render :layout => 'plain'
     end
  end
  
  def download_import
    isd = IscShipmentData.find(params[:isd]) rescue nil

    unless isd.nil?
      filepath = Rails.root.join(Constant::DIR_SF, isd.file_name)
      send_file filepath, :type => 'application/vnd.ms-excel', :disposition => 'attachment'
     else
       render :text => "Error: #{t(:invalid_url)}"
    end
  end
  
  def download_xls
    asset = Asset.find(params[:id]) rescue nil
    unless asset.nil?
      send_file Constant::XLS_PATH + "#{asset.name}", :type => 'application/vnd.ms-excel', :disposition => 'attachment'
     else
       render :text => "Error #{t(:invalid_url)}"
    end
  end

  def download_csv
    asset = Asset.find(params[:id]) rescue nil

    unless asset.nil?
      send_file asset.get_csvfile, :type => 'text/csv', :disposition => 'attachment'
    else
       render :text => t(:invalid_url)
    end
  end
  
  def spreadsheets
    raise t(:invalid_site) if session[:site_id].nil?

    unless params[:site_id].nil?
      site = Site.find(params[:site_id])
      raise t(:invalid_site) if site.nil?
      session[:site_id] = params[:site_id] unless site.nil? 
    end
    
    site_id = session[:site_id]
    @sites = current_user.sites_for_select
    @spreadsheets = Asset.order_spreadsheets(site_id)
    nosheets_orders = OrdersToSupplier.new_westmead_orders(site_id)
    @dates_ots = nosheets_orders.group_by(&:createdat)
  end
  
  def check_gen_xls
    @asset = Asset.find(params[:asset_id]) rescue nil
    render :text => t(:invalid_file) if @asset.nil?
    @missing_orders = []
        
    begin
      raise t(:file_notexist) if !File.exists? Rails.root.join(Constant::DIR_XLS, @asset.name)
      otss = OrdersToSupplier.where("oc_version=2 AND asset_id = ?", @asset.id)
      from_xls_order_ids = @asset.get_orders_from_file

      otss.each do |ots|
        items = ots.order_string[:order_params]['itemsString'].split(":~:") rescue []

        unless items.empty?
          items.each do |item|
            product_code, punit, qty = item.split("~")
            order_id = ots.order_id.to_s
            order_id += "_#{ots.split_flag}" unless ots.split_flag.nil?
            order_row = "#{order_id}***#{product_code.upcase}***#{qty}"

            @missing_orders << [ots, product_code, qty] if !from_xls_order_ids.include? order_row
          end
        end
      end
    rescue Exception => e
      @asset.errors.add(:base, e.message)
    end

    render :layout => 'plain'
  end
 
  def check_custname
    @asset = Asset.find(params[:asset_id]) rescue nil
    render :text => t(:invalid_file) if @asset.nil?
    @orders = {}

    begin
      raise t(:file_notexist) if !File.exists? Rails.root.join(Constant::DIR_XLS, @asset.name)
      @asset.get_columns_from_file.each do |row|
        cols = row.split("***")
        site_id = Helpers.get_site_id(cols.first)
        IscOrder.reconfigure_db(site_id)
        order = IscOrder.find(cols.first.to_i)
        
        unless order.nil?
          @orders["#{order.orderid}"] = {}
          @orders["#{order.orderid}"][:order_address] = order.isc_order_address
          @orders["#{order.orderid}"][:file] = row
        end
      end
    rescue Exception => e
      @asset.errors.add(:base, e.message)
    end

    render :layout => 'plain'
  end

  def check_qty_duplicate
    begin
      @probable_duplicates = OrderProcessing.get_possible_duplicates(session[:site_id], params[:date])
      @site  = Site.find(session[:site_id])
      @sites = current_user.sites_for_select
    rescue Exception => e
      render :text => "Error: #{e.message}"
    end
  end
  
  def check_duplicate
    begin
      @site = Site.find(session[:site_id])
      @sites = current_user.sites_for_select
      @duplicates = OrdersToSupplier.check_duplicate(session[:site_id], params[:date])
    rescue Exception => e
      render :text => "Error: #{e.message}"
    end
  end
  
  def order_summary
    IscOrder.reconfigure_db(session[:site_id])
    @site = Site.find(IscOrder.site_id)
    date = params[:date].blank? ? Time.current.to_date : params[:date].to_date
    @sent = OrdersToSupplier.sent_orders(date.to_date, session[:site_id])
    @notsent = OrderProcessing.notsent_orders(date.to_date, session[:site_id])

    @sites = current_user.sites_for_select
    order_ids = @notsent.map(&:order_id)
    order_ids += @sent.map(&:order_id)
    order_ids.compact!
    order_ids.uniq!
    
    @orders_to_suppliers = OrdersToSupplier.includes(:isc_order => [:isc_customer, :isc_order_address]).
      where("site_id = ? AND created_at >= ? AND created_at < ?", @site.id, date, (date + 1.day).to_date).
      order("created_at DESC, order_id DESC").
      page(params[:page])
    
    order_product_ids = []
    @orders_to_suppliers.map(&:product_ids).each do |prod_ids|
      order_product_ids += prod_ids.split(",")
    end

    order_product_ids = order_product_ids.uniq.compact
    @isc_order_products = IscOrderProduct.where("orderprodid IN (?)", order_product_ids).group_by(&:orderprodid)
 
    respond_to do |format|
      format.html
      format.js
    end
  end
  
  def send_to_queue
    expire_fragment("#{session[:site_id]}-preview_supplier_order_data")
    IscOrder.reconfigure_db(IscOrder.site_id)
    @order_processings = OrderProcessing.where("oc_version=2 AND id IN (?)", params[:chk_order_procid])
    @isc_orders = IscOrder.where("orderid IN (?)", @order_processings.map(&:order_id))
    orders_group = @order_processings.group_by(&:order_id)
    @order_processings.update_all(:created_at => Time.current, :sent => Constant::SENT_TO_QUEUE)
    
    orders_group.keys.each do |k|
      OrderProcessing.send_to_queue(orders_group[k], session[:site_id], session[:test_mode])
    end
    
    respond_to do |format|
      format.js
    end
  end
  
  def updatestatus
    expire_fragment("#{session[:site_id]}-preview_supplier_order_data")
    IscOrder.reconfigure_db(params[:site_id])
    @orders = IscOrder.where("orderid IN (?)", params[:order_id])
    
    ordstatus = case params["mark-as"]
    when "pending"
      Constant::ORDER_PENDING
    when "unpaid"
      Constant::ORDER_UNPAID
    when "paid"
      Constant::ORDER_PAID
    when "submitted"
      Constant::ORDER_SUBMITTED
    when "partially-shipped"
      Constant::ORDER_PARTIALLY_SUBMITTED
    when "shipped"
      Constant::ORDER_SHIPPED
    when "cancelled"
      Constant::ORDER_CANCELLED
    else
      nil
    end
    
    unless ordstatus.nil?
      @orders.each do |order|
        prev_status = order.ordstatus
        order.update_attribute(:ordstatus, ordstatus)
        IscOrder.status_update_email(order, params[:site_id])
        order.reload

        if order.ordstatus == IscOrder::STATUS['Shipped'].first.to_i
          order.set_credits
        else
          order.unset_credits if prev_status == IscOrder::STATUS['Shipped'].first.to_i
        end
      end
    end
    
  end
  
  def preview_data
    IscOrder.reconfigure_db(session[:site_id])
    @orders = IscOrder.not_queued_paid_orders(session[:site_id])
    @order = @orders.first # temporary
    @suppliers_grp = Supplier.all.group_by(&:id)
    OrderProcessing.remove_duplicate(@orders.map(&:orderid), session[:site_id])
  end
  
  def upd_shipping
    expire_fragment("#{session[:site_id]}-preview_supplier_order_data")

    IscOrder.reconfigure_db(session[:site_id])
    @order = IscOrder.find_by_orderid(params[:id])
    
    IscCountry.reconfigure_db(session[:site_id])
    country = IscCountry.find_by_countryiso2(params[:country_iso2])
    params[:isc_order_address][:country] = country.countryname
    params[:isc_order_address][:country_iso2] = country.countryiso2
    params[:isc_order_address][:country_id] = country.countryid
    
    @order.isc_order_address.update_attributes(params[:isc_order_address])
    
    respond_to do |format|
      format.js
    end
  end
  
  def split_by_qty
    expire_fragment("#{session[:site_id]}-preview_supplier_order_data")
    @order_proc = OrderProcessing.find(params[:id])
    @sub_order_processings = []
    @suppliers_grp = Supplier.all.group_by(&:id)

    if params[:val] == "--" || params[:val].blank?
      total_qty = @order_proc.suborders.map(&:qty).sum + @order_proc.qty.to_i
      @order_proc.suborders.delete_all

      @order_proc.qty =  total_qty
      @order_proc.split_by_val = nil
      @order_proc.save
    else
      @sub_order_processings = @order_proc.split_order(params[:val], session[:site_id]) if @order_proc.suborders.empty? 
    end

    respond_to do |format|
      format.html
      format.js
    end
  end
  
  def ajax_edit_shipping
    IscOrder.reconfigure_db(session[:site_id])
    @order = IscOrder.find(params[:id].to_i)
    @countries = IscCountry.for_select
    
    respond_to do |format|
      format.js
    end
  end
  
  def shipping    
    if request.put? || request.post?
      expire_fragment("#{session[:site_id]}-preview_supplier_order_data")
      @isc_order = IscOrder.find(params[:id])
      
      respond_to do |format|
        if @isc_order
          address = @isc_order.isc_order_address
          address.update_attributes(params[:isc_order_address]) unless address.nil?

          format.js
          format.html
        else
          format.js { @isc_order }
        end
      end
      
    end  
  end
  
  def edit_shipping
    @isc_order = IscOrder.includes(:isc_order_products).find(params[:id])
    @countries = IscCountry.for_select
    
    respond_to do |format|
      format.html
      format.js
    end
  end

  def orderdetails
    IscOrder.reconfigure_db(session[:site_id])
    @isc_order = IscOrder.includes(:isc_order_products, :isc_shipment_datas).find_by_orderid(params[:id])
    @order_products = @isc_order.isc_order_products
    @orders_to_suppliers = OrdersToSupplier.where("order_id = ?", @isc_order.orderid).order("created_at DESC")

    respond_to do |format|
      format.html
      format.js
    end
  end

  def billingdetails
    @isc_order = IscOrder.find(params[:id])

    respond_to do |format|
      format.html
      format.js
    end
  end
  
  def shippingdetails
    IscOrder.reconfigure_db(session[:site_id])
    @isc_order = IscOrder.includes(:isc_customer).find(params[:id])

    respond_to do |format|
      format.html
      format.js
    end
  end  

  def index
    @sites = current_user.sites
    @paid_cache_fragment = nil
    
    unless params[:site_id].nil?
      session[:site_id] = params[:site_id]
      IscOrder.reconfigure_db(params[:site_id])
    else
      IscOrder.reconfigure_db(session[:site_id])
    end

      @orders = IscOrder.get_orders(params)
      @suppliers = Supplier.active_suppliers
      @statuses = IscOrderStatus.status_hash

      if params[:status] == IscOrder::PAID
        @result = OrderProcessing.createnew_per_orderline(@orders, session[:site_id])

        ids = @orders.map(&:orderid).join("")
        @paid_cache_fragment = Digest::SHA1.hexdigest("#{session[:site_id]}-#{ids}")
        if !Rails.cache.exist? "views/#{@paid_cache_fragment}"
          expire_fragment("#{session[:site_id]}-preview_supplier_order_data")
        end
        check_preview_fragments(session[:site_id])
      end

    respond_to do |format|
      format.html
      format.js
    end
  end

  def index_datatables
    @sites = current_user.sites
    
    unless params[:site_id].nil?
      session[:site_id] = params[:site_id]
      IscOrder.reconfigure_db(params[:site_id])
    else
      IscOrder.reconfigure_db(session[:site_id])
    end

    @suppliers = Supplier.active_suppliers
    @statuses = IscOrderStatus.status_hash
    
    OrderProcessing.createnew_per_orderline(@orders) if params[:status] == IscOrder::PAID

    respond_to do |format|
      format.html
      format.json { render json: IscOrdersDatatable.new(view_context) }
    end
  end    
end
