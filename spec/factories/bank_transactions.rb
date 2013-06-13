# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :bank_transaction do
    sequence_id 1
    bank_date "2012-10-23"
    transaction_amt "9.99"
    balance "9.99"
    customer_notes "MyString"
    filename "MyString"
    order_ids ""
    site_id Constant::BK_ID
    status_change_date "2012-10-23 13:32:27"
    staff_comments "MyString"
    bank_id 1
  end
end
