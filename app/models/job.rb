#encoding: utf-8
class Job < ActiveRecord::Base
  set_table_name "delayed_jobs"
  
  serialize :handler
end
