# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :supplier do
    
    factory :supplier_sava do
      company_name "SAVA"
    end

    factory :supplier_wm do
      company_name "Westmead"
    end
    
  end
end
