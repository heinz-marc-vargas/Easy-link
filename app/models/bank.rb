class Bank < ActiveRecord::Base
  belongs_to :site
  has_many :bank_transactions
end