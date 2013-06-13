# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :isc_order do  
    orderid "30001234"
    ordstatus 1
    deleted 1
    ordtoken 123456
    orddate Time.current.to_i
    ordcustid 123
    ordtotalqty 1

    factory :isc_order_deleted do
      ordstatus 0
    end

    factory :isc_order_with_products do
      ignore do
        posts_count 1
      end            
              
      after(:create) do |order, evaluator|
        FactoryGirl.create_list(:isc_order_product, evaluator.posts_count, isc_order: order)
      end
    end
    
  end

end
