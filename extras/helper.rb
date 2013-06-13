#require 'launchy'
require 'webrat'

module Helper
  def self.sign_in
    visit '/users/sign_in'
    fill_in "Email", :with => @visitor[:email]
    fill_in "Password", :with => @visitor[:password]
    click_button "Sign in"
  end
end

