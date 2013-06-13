#encoding: utf-8
require 'spec_helper'

describe OrdersController do

  before (:each) do
    @user = FactoryGirl.create(:user_valid)
    sign_in @user

    @site = Site.find_by_sitecode("BK")
    IscOrder.reconfigure_db(@site.id)
    @orderh = FactoryGirl.attributes_for(:isc_order)

    order = IscOrder.where("orderid=?", @orderh[:orderid])
    order.delete_all
    sp = ShopProduct.where("isc_product_id IS NOT NULL")
    sp.delete_all
    
    iop = IscOrderProduct.where("orderorderid=?", @orderh[:orderid])
    iop.delete_all
    
    @supp_sava = Supplier.find_by_company_name("SAVA") rescue FactoryGirl.create(:supplier_sava)
    @supp_wm = Supplier.find_by_company_name("Westmead") rescue FactoryGirl.create(:supplier_wm)
  end

  describe "GET #change_supplier" do
    it "should be able to change supplier from preview supplier data page" do
      @order = FactoryGirl.create(:isc_order_with_products)
      shop_product = FactoryGirl.create(:shop_product)
      result = OrderProcessing.create_order_processing(@order.orderid, @site.id)
      @order.reload
      op = @order.order_processings.first
      get :change_supplier, :format => :js, :op_id => op.id, :supplier_id => @supp_wm.id
      
      op.reload
      op.supplier_id.should == @supp_wm.id.to_s
    end
  end

  describe "POST #undelete" do
    it "should undelete an order" do
      @order = FactoryGirl.create(:isc_order_deleted)
      post :undelete, :format => :js, :id => @order.orderid, :site_id => @site.id, :status => IscOrder::STATUS['Pending'].first, :notes => "test notes"
      response.code.should eq("200")
    end
  end

  describe "POST #setnotes" do
    it "should be able to add notes for an Order" do
      @order = IscOrder.find(@orderh[:orderid]) rescue FactoryGirl.create(:isc_order)
      post :setnotes, :id => @order.orderid, :site_id => @site.id, :order_notes => @notes, :format => :js
      response.code.should eq("200")
    end
  end
  
  describe "GET #mark_order_as_paid" do
    it "should be able to mark an order as paid" do
      @order = FactoryGirl.create(:isc_order)
      bt = FactoryGirl.create(:bank_transaction)
      get :mark_order_as_paid, :btid => bt.id, :order_id => @order.id, :site_id => @site.id
      bt.reload
      response.should_not contain("Error")
    end
  end

  describe "Re-Ordering page" do
    it "should be display" do
      get :reorders, :format => :js
      response.code.should eq("200")
    end
    
    it "should display search result" do
      @order = FactoryGirl.create(:isc_order)
      get :reorders, :format => :js, :order_ids => "#{@order.orderid}", :site_id => @site.id
      response.code.should eq("200")
    end
    
    it "should be able to send reorders to supplier " do
      pending("TODO")
      post :send_reorders, :format => :js, :params => {}
      response.code.should eq("200")
    end    
  end
  
  
  describe "Import page" do
    it "should be able to display imports tracking file page" do
      get :imports, :format => :js
      response.code.should eq("200")
    end
    
    it "should be able to upload tracking file" do
      file = Rack::Test::UploadedFile.new("spec/fixtures/files/SV_2013-06-11_test.xls", "application/vnd.ms-excel")
      param = { :file_name => file }
      post :imports, :isc_shipment_data => param
      file = Rails.root.join(Constant::DIR_SF, "SV_2013-06-11_test.xls")
      file.unlink
      response.body.should_not contain("Error")
    end
    
    it "should read xls uploaded for missing products and display in page" do
      pending;
      get :check_shipping_xls, :isd => 1
      response.body.should_not contain("Error")
    end

    it "should return error when file cant be downloaded or not found" do
      get :download_import, :isd => 1
      response.body.should contain("Error")
    end
        
    it "should be able to download imported file if it exists" do
      get :download_import, :isd => 1
      response.code.should eq("200")
    end
    
  end

  describe "Spreadsheets page" do
    it "should display list of westmeadfiles generated" do
      get :spreadsheets, :format => :js
      response.code.should eq("200")
    end
    
    it "should display list of westmead files from a different site" do
      get :spreadsheets, :format => :js, :site_id => @site.id
      response.code.should eq("200")
    end
    
    it "should be able to download xls version of the westmead file" do
      file_src = Rails.root.join("spec/fixtures/files/SV_2013-06-11_test.xls")
      file_to = Rails.root.join("data/xls/SV_2013-06-11_test.xls")
      FileUtils.cp file_src, file_to
      asset = FactoryGirl.create(:asset)
      
      get :download_xls, :id => asset.id
      file_to.unlink
      response.code.should eq("200")
    end

    it "should be able to download csv version of the westmead file" do
      file_src = Rails.root.join("spec/fixtures/files/SV_2013-06-11_test.xls")
      file_to = Rails.root.join("data/xls/SV_2013-06-11_test.xls")
      FileUtils.cp file_src, file_to
      asset = FactoryGirl.create(:asset)
      
      get :download_csv, :id => asset.id
      file_to.unlink
      response.code.should eq("200")
    end

    it "should check for missing orders inside the westmead files" do
      file_src = Rails.root.join("spec/fixtures/files/SV_2013-06-11_test.xls")
      file_to = Rails.root.join("data/xls/SV_2013-06-11_test.xls")
      FileUtils.cp file_src, file_to
      asset = FactoryGirl.create(:asset)
      
      get :check_gen_xls, :asset_id => asset.id
      file_to.unlink
      response.code.should eq("200")
    end

    it "should be able to check for duplicate name in westmead file" do
      file_src = Rails.root.join("spec/fixtures/files/SV_2013-06-11_test.xls")
      file_to = Rails.root.join("data/xls/SV_2013-06-11_test.xls")
      FileUtils.cp file_src, file_to
      asset = FactoryGirl.create(:asset)
      
      get :check_custname, :asset_id => asset.id
      file_to.unlink
      response.code.should eq("200")
    end

  end
  
  it "should be able to display possible quantity duplicates page" do
    get :check_qty_duplicate, :format => :js
    response.body.should_not contain("Error")
  end
  
  it "should be able to check possible duplicate orders with site and date" do
    get :check_qty_duplicate, :format => :js, :site_id => @site.id, :date => "13-05-2013"
    response.code.should eq("200")
  end
  
  it "should be able to check duplicate orders page" do
    get :check_duplicate, :format => :js
    response.code.should eq("200")
  end

  it "should be able to check duplicate orders page with site and date" do
    get :check_duplicate, :format => :js, :site_id => @site.id, :date => "13-05-2013"
    response.body.should_not contain("Error")
  end

  describe "Oder Summary"  do
    it "should be able to display order summary " do
      get :order_summary, :format => :js
      response.code.should eq('200')
    end
    
    it "should show summary with site and date set" do
      get :order_summary, :format => :js, :site_id => @site.id, :date => "13-05-2013"
      response.code.should eq('200')
    end
  end
  
  it "should be able to send orders unsent orders to queue" do
    pending("TODO")
    #send_to_queue
  end
  
  it "should be able to update order status" do
    @order = FactoryGirl.create(:isc_order)
    post :updatestatus, :format => :js, "mark-as" => "pending", :order_id => @order.id, :site_id => @site.id
    response.code.should eq("200")
  end
  
  it "should be able to display preview supplier data page" do
    get :preview_data, :format => :js, :site_id => @site.id
    response.code.should eq("200")
  end
  
  it "should be able to update shipping information " do
    @order = FactoryGirl.create(:isc_order)
    ioa = FactoryGirl.attributes_for(:isc_order_address)
    ioa[:order_id] = @order.orderid
    ioa = IscOrderAddress.create!(ioa)
    puts ioa.inspect
    
    param = {
      :address_1 => "address 1",
      :address_2 => "address 2",
      :city => "city",
      :state => "state",
      :zip => "123123"
    }

    post :upd_shipping, :format => :js, :id => @order.id, :country_iso2 => "JP", :isc_order_address => param
    response.code.should eq("200")
  end
  
  describe "Splitting quantity in preview supplier data" do
    it "should not allow splitting if quantity is not greater than 10" do
      pending;
      #split_by_qty
    end
    
    it "should be able to split order if quantity is greater than 10" do
      pending;
      #split_by_qty
    end
  end
  
  it "should display edit shipping form" do
    pending;
    #ajax_edit_shipping
  end
  
  it "should display shipping details page" do
    pending;
    #shipping
  end
  
  it "should display edit shipping page" do
    pending;
    #edit_shipping
  end
  
  it "should display order details" do
    pending;
    #orderdetails
  end
  
  it "should display billing details" do
    pending;
    #billingdetails
  end
  
  it "should display shipping details" do
    pending;
    #shippingdetails
  end
  
  it "should the list of orders" do
    pending;
    #index
  end
end