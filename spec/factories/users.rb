FactoryGirl.define do

  factory :user do
    first_name "John"
    last_name  "Doe"
    email "johndoe@example.com"
    password "foobar123"
    password_confirmation "foobar123"
    
    factory :user_valid do
      roles_mask 4
      usertype "services"
    end
    
    factory :user_invalid do
      first_name ""
      last_name  ""
      email ""
      password ""
      password_confirmation ""
    end

    factory :user_invalidemail do
      first_name "John"
      last_name  "Doe"
      email "tthis is invalid email"
      password "foobar"
      password_confirmation "foobar"
    end    
    
  end
end
