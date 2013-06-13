class ExternalSalesChannels < ActiveRecord::Base
  set_primary_key "id"
  has_many :bank_transactions
end
