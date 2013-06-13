#encoding: utf-8
require 'spec_helper'

describe BankTransactionsController do

  before (:each) do
    @user = FactoryGirl.create(:user_valid)
    sign_in @user
  end
  
  describe "GET #export" do
    it "should respond and return a filename" do
      bank = Bank.find_by_bank_name_and_site_id("Rakuten", Constant::BK_ID)
      get :export, :yr_month => Time.now.month, :bank_id => bank.id
      response.should_not contain("Error")
    end
  end

 it "GET #set_orderid" do
    site = Site.find_by_sitecode("BK")
    bt = FactoryGirl.create(:bank_transaction)
    IscOrder.reconfigure_db(site.id)
    order = FactoryGirl.build(:isc_order)

    get :set_orderid, :format => :js, :btid => bt.id , :order_id => order.id
    response.code.should eq("200")
  end
  
  describe "GET #export_download" do
    it "should respond and receive file if file exists" do
      bank = Bank.find_by_bank_name_and_site_id("Rakuten", Constant::BK_ID)
      get :export, :yr_month => "#{Time.now.year}-#{Time.now.strftime('%m')}", :bank_id => bank.id
      json = response.body.split('":"')
      
      get :export_download, :file => json[1].chop.chop
      response.header.should contain("attachment")
    end
    
    it "should return error if file doesnt exists" do
      filename = "non-existence-file"
      get :export_download, :file => filename
      response.should contain("Error")
    end
  end

  describe "GET #import_payment" do
    it "should render import_payment page" do
      get :import_payment, :format => :js
      @error_message.should be_nil
    end
    
    it "should show the page" do
      get :import_payment, :format => :js
      response.body.should contain("Import Payments")
    end
  end
  
  describe "POST #import_payment" do
    it "should able to upload rakuten file" do
      @file = fixture_file_upload("/files/rakuten.csv")
      post :import_payment, :upload => @file
      @error_message.should be_nil
    end
  end
  
  describe "POST #update_sales_channel" do
    it "should update other_sales_channel_id field" do
      bt = FactoryGirl.create(:bank_transaction)
      post :update_sales_channel, :format => :js, :id => bt.id, :channel_id => 1
      response.code.should eq("200")
    end
  end
    
#  describe "GET #save_changes" do
#    it "should save the changes" do
#      bt = FactoryGirl.create(:bank_transaction)
#      btrans = {
#        :trxn_id => bt.id,
#        :order_ids => bt.order_ids,
#        :site_id => bt.site_id,
#        :staff_comments => ""
#      }
#
#      post :save_changes, :bank_transactions => btrans, :sales_channel => 1
#    end
#  end

  describe "GET #index" do
    it "should render index page" do
      get :index, :format => :js
      response.code.should eq("200")
    end
  end
  
  describe "GET #set_sequence" do
    it "should update the sequence column" do
      bt = FactoryGirl.create(:bank_transaction)
      bt_ids = [bt.id]
      get :set_sequence, :format => :js, :sequence_id => bt_ids
      response.code.should eq("200")
    end
  end
  
end
