class AuditsController < ApplicationController
  before_filter :authenticate_user!
  
  require 'will_paginate/array'
  
  def show
    @audits = Audit.lists(params[:page]) #.find(:all, :order => "id DESC")
    
    respond_to do |format|
      format.html
      format.js
    end
  end

  def audit_record
  end

  def audit_object
  end
  
end
