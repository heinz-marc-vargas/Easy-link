class UsersController < ApplicationController
  before_filter :authenticate_user!

  def index
    respond_to do |format|
      format.html
      format.js
      format.json { render json: UsersDatatable.new(view_context) }
    end
  end

  def show
    @user = User.find(params[:id]) rescue nil
  end

  def new
    @user = User.new
    @sites = Site.all
    unauthorized! if cannot? :create, User
    
    respond_to do |format|
      format.html
      format.js
    end
  end

  def edit
    unauthorized! if cannot? :update, User
    @user = User.find(params[:id])
    @sites = Site.all

    
    respond_to do |format|
      format.html
      format.js
    end    
  end

  def user_create
    @user = User.new(params[:user])
    @user.roles = [params[:user][:usertype]]
    
    respond_to do |format|
      if @user.save
        attach_folder = Rails.root.join('data', 'email_attachments', "#{@user.id}")
        FileUtils.mkdir_p(attach_folder) if !File.exists? attach_folder
        format.html { redirect_to(@user) }
        format.js
      else
        format.js { @user }
      end
    end
  end

  def lock
    @user = User.find(params[:id])
    @user.update_attribute(:locked_at, Time.now)
    
    respond_to do |format|
      format.html { redirect_to users_url }
      format.js
    end
  end
  
  def unlock
    @user = User.find(params[:id])
    @user.unlock_access!
    
    respond_to do |format|
      format.html { redirect_to users_url }
      format.js
    end
  end
  
  def update
    @user = User.find(params[:id])
    @user.roles = [params[:user][:usertype]]
    
    if params[:user][:password].blank? && params[:user][:password_confirmation].blank?
      params[:user].delete(:password)
      params[:user].delete(:password_confirmation)
    end

    respond_to do |format|
      if @user.update_attributes(params[:user])
        format.html { redirect_to users_url, :notice => "User was successfully updated" }
        format.js
      else
        format.html { render :action => :edit }
        format.js { @user }
      end
    end    
    
    
  end

  def destroy
    @user = User.find(params[:id])
    @user.destroy

    respond_to do |format|
      format.html { redirect_to users_url }
      format.js
    end
  end

end
