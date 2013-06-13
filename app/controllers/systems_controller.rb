class SystemsController < ApplicationController

  def index
    @delayed_job_check = %x[ps -ef | grep delayed_job]
    
    respond_to do |format|
      format.html
      format.js
    end
  end
  
end
