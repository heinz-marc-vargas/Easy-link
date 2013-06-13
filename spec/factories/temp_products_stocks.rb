# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :temp_products_stock do
    name "MyString"
    supplier_id 1
    ext_product_id "MyString"
    qty 1
    expiry_date "2012-11-12"
    batch_code "MyString"
    filename "MyString"
  end
end
