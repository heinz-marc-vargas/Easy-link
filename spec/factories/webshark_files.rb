# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :webshark_file do
    filename "MyString"
    uploader_id 1
     ""
    status "MyString"
    logs "MyText"
    extra "MyText"
    site_id 1
  end
end
