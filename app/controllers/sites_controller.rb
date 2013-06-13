class SitesController < ApplicationController
  before_filter :authenticate_user!

  def index
    #@sites = Site.lists(params[:page])

    respond_to do |format|
      format.html
      format.js
      format.json { render json: SitesDatatable.new(view_context) }
    end
  end

  def show
    @user = User.find(params[:id])
  end

  def new
    @site = Site.new
    
    respond_to do |format|
      format.html
      format.js
    end
  end

  def edit
    @site = Site.find(params[:id])
    
    respond_to do |format|
      format.html
      format.js
    end    
  end

  def create
    @site = Site.new(params[:site])

    respond_to do |format|
      if @site.save
        format.html { redirect_to(@site) }
        format.js
      else
        format.js { @site }
      end
    end
  end
  
  def update
    @site = Site.find(params[:id])

    respond_to do |format|
      if @site.update_attributes(params[:site])
        format.html { redirect_to sites_url, :notice => "Site successfully updated" }
        format.js
      else
        format.html { render :action => :edit }
        format.js { @site }
      end
    end    
  end

  def destroy
    @site = Site.find(params[:id])
    @site.destroy

    respond_to do |format|
      format.html { redirect_to sites_url }
      format.js
    end
  end

end
