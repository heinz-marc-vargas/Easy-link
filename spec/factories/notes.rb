# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :note do
    notable_id 1
    notable_type "MyString"
    contents "MyText"
    user_id 1
  end
end
