Feature: Manage ISC Orders
  I should be authorized

  Background:
    Given I am logged-in
    
  Scenario: Able to undelete an order
    Given an Order from a given site and notes "some reason for undeleting"
    When POST request to #undelete
    Then Order should now be undeleted
  
  Scenario: Able to #setnotes
    Given an Order and site and notes "test notes"
    When setnotes-form is submitted
    Then Order should have additional note

  @focus  
  Scenario: Able to change supplier from Preview Data
    Given Supplier ID <supplier_id> AND OrderProcessing ID <op_id>
    When GET request to #change_supplier
    Then OrderProcessing with id <op_id> should have a new supplier_id
  
  Scenario: Able to mark order as paid #mark_order_as_paid
    Given Order Id <order_id> Site Id <site_id> BankTransaction Id <btid>
    When GET request to #mark_order_as_paid
    Then Order should be mark as paid
  
  Scenario: Able to send reorders
    Given the params
    When POST request to #send_reorders
    Then I should get new OrdersToSupplier records created
  
  Scenario: Able to view page re-order page
    Given Site ID <site_id> AND Order IDS <order_id,order_id>
    When GET request to #reorders
    Then I should get found orders
  
  Scenario: Able to view import shipping numbers page
    When GET request to #imports
    Then I should see the import shipping page
  
  Scenario: Able to import a shipping number file
    Given File <file>
    When POST request to #imports
    Then I should be able to see the imported file in the list
  
  Scenario: Able to view spreadsheet
    When GET request to #generate_spreadsheet
    Then I should be able to view the spreadsheets page
  
  Scenario: Able to generate spreadsheet for orders for current day
    Given Site ID <site_id>
    When POST request to #generate_spreadsheet
    Then I should be able to see the new list of spreadsheets
  
  Scenario: Check Uploaded shipping numbers
    Given the IscShipmentData ID <isd>
    When GET request to #check_shipping_xls
    Then I should be able to the list of Tracking records
  
  Scenario: Able to download xls version of westmead files
    Given TrackingFile ID <id>
    When GET request to #download_xls
    Then I should be able to download the file
  
  Scenario: Able to download csv version of westmead files
    Given TrackingFile ID <id>
    When GET request to #download_csv
    Then I should be able to download the file
  
  Scenario: Able to view the list of Westmead files
    Given Site ID <site_id>
    When GET request to #spreadsheets
    Then I should be view the list of westmead files
  
  Scenario: Check for missing westmead orders
    Given Asset ID <asset_id>
    When GET request to #check_gen_xls
    Then I should be able to see the list of missing Orders
  
  Scenario: Check for unmatch customer names
    Given Asset ID <asset_id>
    When GET request to #check_custname
    Then I should be able to see list of shipping records
  
  Scenario: Check for possible quantity Duplicates
    Given Site ID <site_id> and Date <yyyy-mm-dd>
    When GET request to #check_qty_duplicate
    Then I should be able to see the possible duplicate orders
    
  Scenario: Check for Duplicate orders sent to supplier
    Given Site ID <site_id> and Date <yyyy-mm-dd>
    When GET request to #check_duplicate
    Then I should be able to see the list of duplicate orders
    
  Scenario: Able to view Order summary page
    Given Site ID <site_id> and Date <yyyy-mm-dd>
    When GET request to #order_summary
    Then I should be able to view the list of Orders sent to supplier