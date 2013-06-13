# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :shop_product do
    association :product, factory: :product, strategy: :create
  
    supplier_id 1
    site_id 9
    isc_product_id 123
    bundle_qty 1
  end
end
