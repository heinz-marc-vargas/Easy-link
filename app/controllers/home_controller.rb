class HomeController < ApplicationController
  protect_from_forgery
  layout 'login'

  def index
    @user = User.new
  end
end
