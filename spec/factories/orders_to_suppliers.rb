# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :orders_to_supplier do
    site_id 1
    order_id 1
    split_flag "MyString"
    supplier_ids "MyString"
    product_ids "MyString"
    order_string "MyString"
    response_status "MyText"
    sent_to_wm 1
  end
end
