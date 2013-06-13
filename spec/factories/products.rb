# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :product do
    
    supplier_id 1
    ext_product_id 111
    name "Generic item 10mg"
    uid 0
    
    factory :product_with_shop_products do

      ignore do
        posts_count 1
      end
      
      after(:create) do |prod, evaluator|
        FactoryGirl.create_list(:shop_product, evaluator.posts_count, product: prod)
      end
    end
    
  end
end
