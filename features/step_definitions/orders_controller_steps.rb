Given /^I am logged-in$/ do
  sign_in
end


Given /^an Order from a given site and notes "(.*?)"$/ do |notes|
  create_order("BK")
end

When /^POST request to \#undelete$/ do
  post undelete_order_path(@order), :format => :js
end

Then /^Order should now be undeleted$/ do
  @order.deleted != 1
  @order.destroy
end


Given /^an Order and site and notes "(.*?)"$/ do |notes|
  @notes = notes
  create_order("BK")
end

When /^setnotes-form is submitted$/ do
  page.driver.post(setnotes_order_path(:id => @order.orderid, :site_id => @site.id, :order_notes => @notes, :format => :js)) 
end

Then /^Order should have additional note$/ do
  @order.reload
  @order.ordnotes.to_s != ""
end


Given /^Supplier ID <supplier_id> AND OrderProcessing ID <op_id>$/ do
  pending # express the regexp above with the code you wish you had
end

When /^GET request to \#change_supplier$/ do
  pending # express the regexp above with the code you wish you had
end

Then /^OrderProcessing with id <op_id> should have a new supplier_id$/ do
  pending # express the regexp above with the code you wish you had
end

Given /^Order Id <order_id> Site Id <site_id> BankTransaction Id <btid>$/ do
  pending # express the regexp above with the code you wish you had
end

When /^GET request to \#mark_order_as_paid$/ do
  pending # express the regexp above with the code you wish you had
end

Then /^Order should be mark as paid$/ do
  pending # express the regexp above with the code you wish you had
end

Given /^the params$/ do
  pending # express the regexp above with the code you wish you had
end

When /^POST request to \#send_reorders$/ do
  pending # express the regexp above with the code you wish you had
end

Then /^I should get new OrdersToSupplier records created$/ do
  pending # express the regexp above with the code you wish you had
end

Given /^Site ID <site_id> AND Order IDS <order_id,order_id>$/ do
  pending # express the regexp above with the code you wish you had
end

When /^GET request to \#reorders$/ do
  pending # express the regexp above with the code you wish you had
end

Then /^I should get found orders$/ do
  pending # express the regexp above with the code you wish you had
end

When /^GET request to \#imports$/ do
  pending # express the regexp above with the code you wish you had
end

Then /^I should see the import shipping page$/ do
  pending # express the regexp above with the code you wish you had
end

Given /^File <file>$/ do
  pending # express the regexp above with the code you wish you had
end

When /^POST request to \#imports$/ do
  pending # express the regexp above with the code you wish you had
end

Then /^I should be able to see the imported file in the list$/ do
  pending # express the regexp above with the code you wish you had
end

When /^GET request to \#generate_spreadsheet$/ do
  pending # express the regexp above with the code you wish you had
end

Then /^I should be able to view the spreadsheets page$/ do
  pending # express the regexp above with the code you wish you had
end

Given /^Site ID <site_id>$/ do
  pending # express the regexp above with the code you wish you had
end

When /^POST request to \#generate_spreadsheet$/ do
  pending # express the regexp above with the code you wish you had
end

Then /^I should be able to see the new list of spreadsheets$/ do
  pending # express the regexp above with the code you wish you had
end

Given /^the IscShipmentData ID <isd>$/ do
  pending # express the regexp above with the code you wish you had
end

When /^GET request to \#check_shipping_xls$/ do
  pending # express the regexp above with the code you wish you had
end

Then /^I should be able to the list of Tracking records$/ do
  pending # express the regexp above with the code you wish you had
end

Given /^TrackingFile ID <id>$/ do
  pending # express the regexp above with the code you wish you had
end

When /^GET request to \#download_xls$/ do
  pending # express the regexp above with the code you wish you had
end

Then /^I should be able to download the file$/ do
  pending # express the regexp above with the code you wish you had
end

When /^GET request to \#download_csv$/ do
  pending # express the regexp above with the code you wish you had
end

When /^GET request to \#spreadsheets$/ do
  pending # express the regexp above with the code you wish you had
end

Then /^I should be view the list of westmead files$/ do
  pending # express the regexp above with the code you wish you had
end

Given /^Asset ID <asset_id>$/ do
  pending # express the regexp above with the code you wish you had
end

When /^GET request to \#check_gen_xls$/ do
  pending # express the regexp above with the code you wish you had
end

Then /^I should be able to see the list of missing Orders$/ do
  pending # express the regexp above with the code you wish you had
end

When /^GET request to \#check_custname$/ do
  pending # express the regexp above with the code you wish you had
end

Then /^I should be able to see list of shipping records$/ do
  pending # express the regexp above with the code you wish you had
end

Given /^Site ID <site_id> and Date <yyyy\-mm\-dd>$/ do
  pending # express the regexp above with the code you wish you had
end

When /^GET request to \#check_qty_duplicate$/ do
  pending # express the regexp above with the code you wish you had
end

Then /^I should be able to see the possible duplicate orders$/ do
  pending # express the regexp above with the code you wish you had
end

When /^GET request to \#check_duplicate$/ do
  pending # express the regexp above with the code you wish you had
end

Then /^I should be able to see the list of duplicate orders$/ do
  pending # express the regexp above with the code you wish you had
end

When /^GET request to \#order_summary$/ do
  pending # express the regexp above with the code you wish you had
end

Then /^I should be able to view the list of Orders sent to supplier$/ do
  pending # express the regexp above with the code you wish you had
end