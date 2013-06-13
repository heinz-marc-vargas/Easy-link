#encoding: utf-8
class MagentoOrdersController < ApplicationController
  before_filter :authenticate_user!
  before_filter :set_current_site

  before_filter :magento_connect, :only => [ :index, :update_shipping, :edit_shipping, :orderdetails, :billingdetails, :shippingdetails, :ajax_edit_shipping, :upd_shipping ]
  
  def index
    @sites = current_user.sites
    @orders = []
    
    if params[:q].nil?
        if params[:status].blank?
          @orders = @magento.call("sales_order.list")
        else
          @orders = @magento.call("sales_order.list", :status => params[:status].downcase)
        end
    else
      if params[:status].blank?
        @orders += @magento.call("sales_order.list", :increment_id => { :like => "%#{params[:q]}%" } )
        @orders += @magento.call("sales_order.list", :customer_firstname => { :like => "%#{params[:q]}%" } )
        @orders += @magento.call("sales_order.list", :customer_lastname => { :like => "%#{params[:q]}%" })
        @orders += @magento.call("sales_order.list", :customer_email => { :like => "%#{params[:q]}%" })
      else
        @orders += @magento.call("sales_order.list", :status => params[:status].downcase, :increment_id => { :like => "%#{params[:q]}%" } )
        @orders += @magento.call("sales_order.list", :status => params[:status].downcase, :customer_firstname => { :like => "%#{params[:q]}%" } )
        @orders += @magento.call("sales_order.list", :status => params[:status].downcase, :customer_lastname => { :like => "%#{params[:q]}%" })
        @orders += @magento.call("sales_order.list", :status => params[:status].downcase, :customer_email => { :like => "%#{params[:q]}%" })
      end
    end
    
    @orders.compact!
    @orders.uniq!
  end

  def populate_order_data
    ops = OrderProcessing.where("order_id IN (?)", params[:order_ids].split(","))
    existing_order_ids = ops.map(&:order_id).uniq
    new_order_ids = params[:order_ids].split(",").select{|oid| oid if !existing_order_ids.include? oid.to_i }
    Mage.populate_order_processings("#{new_order_ids.join(',')}")
  end

  def preview_data
    @site = Site.find_by_sitecode(Constant::PKY_CODE)
    IscOrder.reconfigure_db(@site.id)
    @suppliers_grp = Supplier.all.group_by(&:id)
    @orders = OrderProcessing.where("sent is null and site_id = ?", @site.id).includes(:product).order("order_id DESC").group_by(&:order_id)
  end

  def send_to_queue
    expire_fragment("#{session[:site_id]}-preview_supplier_order_data")
    site = Site.find_by_sitecode(Constant::PKY_CODE)
    IscOrder.reconfigure_db(site.id)
    @order_processings = OrderProcessing.where("oc_version=2 AND id IN (?)", params[:chk_order_procid])
    @isc_orders = IscOrder.where("orderid IN (?)", @order_processings.map(&:order_id))
    orders_group = @order_processings.group_by(&:order_id)

    orders_group.keys.each do |k|
      OrderProcessing.send_to_queue(orders_group[k], site.id, session[:test_mode])
    end

    respond_to do |format|
      format.js
    end
  end
  
  def set_status
    order_ids = params[:order_id].uniq
    status_id = Helpers.get_status_id(params['mark-as'])
    Mage.change_status(order_ids, status_id, params['send-email'].to_i)
  end

  def ajax_edit_shipping
    @order = @magento.call("order.info", params[:id])
    puts @order.inspect
    
    respond_to do |format|
      format.js
    end
  end

  def upd_shipping
    expire_fragment("#{session[:site_id]}-preview_supplier_order_data")
    
    msa = MageShippingAddress.find(params[:order_address_id])
    unless msa.nil?
      msa.street = params[:street]
      msa.city = params[:city]
      msa.region = params[:state]
      msa.postcode = params[:zip]
      msa.save
      
      IscOrder.reconfigure_db(18)
      order = IscOrder.find(params[:id])
      @order = @magento.call("order.info", params[:id])
      unless order.nil?
        order.shipping_address = @order['shipping_address']
        order.billing_address = @order['billing_address']
        order.order_info = @order
        order.save
      end
      
    end
    
    respond_to do |format|
      format.js
    end
  end

  def update_shipping
    puts params.inspect
    
    if request.put? || request.post?
      expire_fragment("#{session[:site_id]}-preview_supplier_order_data")
      @order_id = params[:id]

      @ship_address = MageShippingAddress.find(params[:order_address_id])
      @ship_address.firstname = params[:first_name]
      @ship_address.lastname = params[:last_name]
      @ship_address.street = params[:street]
      @ship_address.city = params[:city]
      @ship_address.postcode = params[:zip]
      @ship_address.email = params[:email]
      @ship_address.telephone = params[:telephone]
      @ship_address.region = params[:state]
      @ship_address.save

      @order = @magento.call("order.info", @order_id)
      IscOrder.reconfigure_db(18)
      order = IscOrder.find(@order_id.to_i)

      unless order.nil?
        order.shipping_address = @order['shipping_address']
        order.billing_address = @order['billing_address']
        order.order_info = @order
        order.save!
      end
      
      respond_to do |format|
        format.js
        format.html
      end
    end  
  end
  
  def edit_shipping
    @order = @magento.call("sales_order.info", params[:id])
    @countries = IscCountry.for_select
    
    respond_to do |format|
      format.html
      format.js
    end
  end
  
  def orderdetails
    @order = @magento.call("sales_order.info", params[:id])
    @orders_to_suppliers = OrdersToSupplier.where("order_id = ?", @order['increment_id']).order("created_at DESC")
    @isc_shipment_datas = IscShipmentData.where("order_id = ?", @order['increment_id']).order("created_at DESC")
    
    respond_to do |format|
      format.html
      format.js
    end
  end

  def billingdetails
    @order = @magento.call("sales_order.info", params[:id])

    respond_to do |format|
      format.html
      format.js
    end
  end
  
  def shippingdetails
    @order = @magento.call("sales_order.info", params[:id])

    respond_to do |format|
      format.html
      format.js
    end
  end

  def change_supplier
    expire_fragment("#{session[:site_id]}-preview_supplier_order_data")
    
    @op = OrderProcessing.find(params[:op_id]) rescue nil
    unless @op.nil?
      @op.update_attribute(:supplier_id, params[:supplier_id])

      #if combis
      combis = OrderProcessing.where("combi_id = ?", @op.id)
      unless combis.empty?
        combis.each do |op|
          op.update_attribute(:supplier_id, params[:supplier_id])
        end
      end
      
      #if order is splitted
      splitted = OrderProcessing.where("parent_order_id = ?", @op.order_id)
      unless splitted.empty?
        splitted.each do |op|
          op.update_attribute(:supplier_id, params[:supplier_id])
        end
      end

    end
    
    respond_to do |format|
      format.js
    end    
  end

  
  private
  def magento_connect
    @magento = MagentoAPI.new(CONFIG[:magento_pkhost], CONFIG[:magento_user], CONFIG[:magento_key], :debug => false)
  end

  def render_nothing
    render :nothing => true
  end

end
