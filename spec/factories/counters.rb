# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :counter do
    paid_orders 1
    submitted_orders 1
    shipped_orders 1
  end
end
