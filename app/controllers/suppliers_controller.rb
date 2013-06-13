class SuppliersController < ApplicationController
  before_filter :authenticate_user!

  def index
    @suppliers = Supplier.lists(params[:page])

    respond_to do |format|
      format.html
      format.js
    end
  end

  def show
    @supplier = Supplier.find(params[:id])
  end

  def new
    @supplier = Supplier.new
    
    respond_to do |format|
      format.html
      format.js
    end
  end

  def edit
    @supplier = Supplier.find(params[:id])
    
    respond_to do |format|
      format.html
      format.js
    end    
  end

  def create
    @supplier = Supplier.new(params[:supplier])

    respond_to do |format|
      if @supplier.save
        format.html { redirect_to(@supplier) }
        format.js
      else
        format.js { @supplier }
      end
    end
  end
  
  def update
    @supplier = Supplier.find(params[:id])

    respond_to do |format|
      if @supplier.update_attributes(params[:supplier])
        format.html { redirect_to suppliers_url, :notice => "Supplier successfully updated" }
        format.js
      else
        format.html { render :action => :edit }
        format.js { @supplier }
      end
    end    
  end

  def destroy
    @supplier = Supplier.find(params[:id])
    @supplier.destroy
    #TODO: need to destroy those related information if needed.

    respond_to do |format|
      format.html { redirect_to suppliers_url }
      format.js
    end
  end

end