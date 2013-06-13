# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :product_processing do
    order_id 1
    orderprodid 1
    product_id 1
    qty 1
    supplier_id 1
    split_by_val "MyString"
    site_id 1
  end
end
