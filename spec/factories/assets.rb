# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :asset do
    name "SV_2013-06-11_test.xls"
    site_id 1
    asset_id 1
    asset_type "MyString"
    order_ids "MyText"
  end
end
