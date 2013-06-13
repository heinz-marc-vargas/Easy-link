# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :cache_fragment do
    name "MyString"
    site_id 1
    status false
  end
end
