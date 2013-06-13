class System < ActiveRecord::Base

  def self.check_delayed_job
    delayed_job_check = %x[ps -ef | grep delayed_job]
    delayed_job_info = delayed_job_check.split("\n")
    need_restart = false
    
    Constant::QNUM_QUEUES.each do |qn, q|  
      if (delayed_job_info.select { |dj| dj.include?("delayed_job.=" + qn) }[0] == nil) 
        need_restart = (need_restart == false)? true : need_restart
      end
    end
    
    if (need_restart == true)
      result = %x[./start_job.sh]
      syst = System.new(:command_ln => "./start_job.sh", :output => result, :command_ran_at => Time.now)
      syst.save
    end
  end
  
  def self.restart_delayed_job(qnum = nil)
    result = nil
    if (qnum != nil)
      result = system("./start_job.sh #{qnum} &") #%x[./start_job.sh #{qnum} &]
      syst = System.new(:command_ln => "./start_job.sh " + qnum.to_s, :output => result, :command_ran_at => Time.now)
      syst.save
    end
    return result
  end
  
end
