require 'spec_helper'

describe BankTransaction do

  before (:each) do
    @site = Site.find_by_sitecode("BK")
    @bt = FactoryGirl.create(:bank_transaction)
    IscOrder.reconfigure_db(@site.id)
    @order = FactoryGirl.build(:isc_order)
  end
  
  it "should be valid site object" do
    @site.should be_valid
  end

  it "should be valid bank_transaction object" do
    @bt.should be_valid
  end

  it "should be valid isc_order object" do
    @order.should be_valid
  end
  
  it "should be able to set_orderid(order_id)" do
    result = @bt.set_orderid(@order.orderid)
    result.should_not be_nil
  end

  it "should be able to update multiple fields update_fields({})" do
    params = { :order_ids => "123456", :status_change_date => Time.current.strftime("%Y-%m-%d %H:%M:%S") }
    @bt.update_fields(params)
    @bt.should be_valid
  end

  #class methods
  describe "mark_as_paid(btid, order_id, site_id)" do
    it "should be invalid if no btid" do
      result = BankTransaction.mark_as_paid(nil, @order.id, @site.id)
      result.should == false
    end

    it "should be invalid if no order_id" do
      result = BankTransaction.mark_as_paid(@bt.id, nil, @site.id)
      result.should == false
    end

    it "should be invalid if no site_id" do
      result = BankTransaction.mark_as_paid(@bt.id, @order.id, nil)
      result.should == false
    end

    it "should be successful" do
      result = BankTransaction.mark_as_paid(@bt.id, @order.id, @site.id)
      result.should == false
    end
  end
  
  it "update_status_change_date(bank_transaction_id = nil)" do
    result = BankTransaction.update_status_change_date(@bt.id)
    result.should be_valid
  end
  
  it "update_other_sales_channel_id(bank_transaction_id = nil, other_sales_channel_id = nil)" do
    result = BankTransaction.update_other_sales_channel_id(@bt.id)
    result.should be_valid
  end
  
  it "should able to (csv_data = [], bank_id, yr_mth)" do
    csv_data << [trxn.order_ids, trxn.bank_date, trxn.transaction_amt, trxn.balance, trxn.customer_notes, balance_tally.to_f, ((payment_tally.nil?) ? "" : "#{payment_tally.to_f}"), trxn.staff_comments, trxn.filename, (trxn.status_change_date.strftime("%Y-%m-%d") rescue "") ]
    file_name = BankTransaction.create_csv(csv_data, bank_id, yr_mth)
    file_name.should be_valid
  end
  
  
  after(:each) do
    @order.destroy
  end
end
