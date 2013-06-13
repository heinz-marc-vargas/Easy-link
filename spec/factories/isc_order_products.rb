# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :isc_order_product do
    association :isc_order, factory: :isc_order, strategy: :create
    
    ordprodid 123
    ordprodsku "ABCCODE123"
    ordprodname "Sample Product name"
    ordprodtype "physical"
    base_price 1234
    price_ex_tax 1234
    ordprodqty 1
    orderprodid 2216037
  end
end
