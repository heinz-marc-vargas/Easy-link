class ExternalSalesChannel < ActiveRecord::Base
  set_table_name "external_sales_channels"
  set_primary_key "id"
  has_many :bank_transactions

end
