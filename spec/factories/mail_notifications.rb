# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :mail_notification do
    order_id 1
    site_id 1
    email "MyString"
    mailable_id 1
    mailable_type "MyString"
  end
end
