# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :tracking_file do
    filename "MyString"
    uploader_id 1
    uploader_type "MyString"
    status "MyString"
  end
end
