class FormsController < ApplicationController
  before_filter :authenticate_user!
  #before_filter :set_current_site
  
  def sava_comms_form
    #session[:active_main_tab] = "forms"
    IscOrder.reconfigure_db(1)
    
    #"to", "from", "cc", "fwd", "content", "attachments"
    @supplier_id = 1
    @unsent_sava_emails = Email.find(:all, :conditions => {:user_id => current_user.id, :supplier_id => @supplier_id, :sent => 0})
    @email = Email.find(params[:email_id].to_i) rescue nil
    
    if User::PETS_TEAM.include? current_user.email
      @from =  "<" + User::PETS_EMAIL + ">"
    elsif User::MEDS_TEAM.include? current_user.email
      @from =  "<" + User::MEDS_EMAIL + ">"
    else
      @from =  "<" + User.find(current_user.id).email + ">"
    end

    @to_cc_list = Email.sava_to_cc_list
    
    arr_size = @to_cc_list.count
    logger.info("PARAMS: " + params.inspect + "\n ARR_SIZE: " + arr_size.to_s)
    
    @to = []
    @cc = []
    
    if (params[:forms] != nil)
      # parse out selected to & cc emails
      until (arr_size < 1)
        if (params[:forms]["to_" + (arr_size - 1).to_s] == "y")
          @to << ("<" + @to_cc_list[(arr_size - 1)] + ">")
        end
      
        if (params[:forms]["cc_" + (arr_size - 1).to_s] == "y")
          @cc << ("<" + @to_cc_list[(arr_size - 1)] + ">")
        end
        arr_size -= 1
      end
    
      logger.info("TO: " +  @to.join(",") + ", FROM: " + @from + ", CC: " + @cc.join(","))
      @subject = (params[:forms][:subject] != nil)? params[:forms][:subject] : ""
      @content = (params[:forms][:content] != nil)? params[:forms][:content] : ""
      logger.info("Subject: " + params[:forms][:subject].inspect + " ==> " + @subject)
      logger.info("Content: " + params[:forms][:content].inspect + " ==> " + @content)
    
      if (params[:forms][:subject] != nil || params[:forms][:content] != nil)
        if (@email == nil)
          @email = Email.new(:user_id => current_user.id, :to => @to.join(","), :from => @from, :cc => @cc.join(","), :subject => @subject, :content => @content.gsub(/\r\n/,"<br/>"), :supplier_id => @supplier_id)
          logger.info("EMAIL: " + @email.inspect)
        else
          @email.to = @to.join(",")
          @email.from = @from
          @email.cc = @cc.join(",")
          @email.subject = @subject
          @email.content = @content.gsub(/\r\n/,"<br/>")
        end
        if (@email.save)
          if (params[:commit] != "Attach File(s)")
            redirect_to :protocol => "https://", :action => "sava_comms_form"  # production
            #redirect_to :action => "sava_comms_form", :email_id => @email.id, :supplier_id => @supplier_id   # on local machine
          else
            redirect_to :protocol => "https://", :action => "attach_files", :email_id => @email.id, :supplier_id => @supplier_id  # production
            #redirect_to :action => "attach_files", :email_id => @email.id, :supplier_id => @supplier_id  # on local machine
          end
        end
      end
    end
  end
  
  def send_all_unsent_to_sava
    supplier_id = 1
    unsent_emails_to_sava = Email.find(:all, :conditions => {:user_id => current_user.id, :supplier_id => supplier_id, :sent => 0})
    unsent_emails_to_sava.each do |e|
      email_to_sava = FormsMailer.send_form_to_sava(e.from, e.to, e.cc, e.subject, e.content, e.attachments, ("data/email_attachments/" + current_user.id.to_s))
      if (email_to_sava.deliver)
        e.sent = 1
        e.save
      end
    end
    
    redirect_to :protocol => "https://", :action => "sava_comms_form"  # production
    #redirect_to :action => "sava_comms_form"   # on local machine
  end
  
  def westmead_comms_form
    session[:active_main_tab] = "forms"
    IscOrder.reconfigure_db(1)
    
    #"to", "from", "cc", "fwd", "content", "attachments"
    @supplier_id = 3
    @unsent_westmead_emails = Email.find(:all, :conditions => {:user_id => current_user.id, :supplier_id => @supplier_id, :sent => 0})
    @email = Email.find(params[:email_id].to_i) rescue nil
    
    if User::PETS_TEAM.include? current_user.email
      @from =  "<" + User::PETS_EMAIL + ">"
    elsif User::MEDS_TEAM.include? current_user.email
      @from =  "<" + User::MEDS_EMAIL + ">"
    else
      @from =  "<" + User.find(current_user.id).email + ">"
    end

    @to_cc_list = Email.wm_to_cc_list
    
    arr_size = @to_cc_list.count
    logger.info("PARAMS: " + params.inspect + "\n ARR_SIZE: " + arr_size.to_s)
    
    @to = []
    @cc = []
    
    if (params[:forms] != nil)
      # parse out selected to & cc emails
      until (arr_size < 1)
        if (params[:forms]["to_" + (arr_size - 1).to_s] == "y")
          @to << ("<" + @to_cc_list[(arr_size - 1)] + ">")
        end
      
        if (params[:forms]["cc_" + (arr_size - 1).to_s] == "y")
          @cc << ("<" + @to_cc_list[(arr_size - 1)] + ">")
        end
        arr_size -= 1
      end
    
      logger.info("TO: " +  @to.join(",") + ", FROM: " + @from + ", CC: " + @cc.join(","))
      @subject = (params[:forms][:subject] != nil)? params[:forms][:subject] : ""
      @content = (params[:forms][:content] != nil)? params[:forms][:content] : ""
      logger.info("Subject: " + params[:forms][:subject].inspect + " ==> " + @subject)
      logger.info("Content: " + params[:forms][:content].inspect + " ==> " + @content)
    
      if (params[:forms][:subject] != nil || params[:forms][:content] != nil)
        if (@email == nil)
          @email = Email.new(:user_id => current_user.id, :to => @to.join(","), :from => @from, :cc => @cc.join(","), :subject => @subject, :content => @content.gsub(/\r\n/,"<br/>"), :supplier_id => @supplier_id)
          logger.info("EMAIL: " + @email.inspect)
        else
          @email.to = @to.join(",")
          @email.from = @from
          @email.cc = @cc.join(",")
          @email.subject = @subject
          @email.content = @content.gsub(/\r\n/,"<br/>")
        end
        if (@email.save)
          if (params[:commit] != "Attach File(s)")
            redirect_to :protocol => "https://", :action => "westmead_comms_form"  # production
            #redirect_to :action => "westmead_comms_form"   # on local machine
          else
            redirect_to :protocol => "https://", :action => "attach_files", :email_id => @email.id, :supplier_id => @supplier_id  # production
            #redirect_to :action => "attach_files", :email_id => @email.id, :supplier_id => @supplier_id  # on local machine
          end
        end
      end
    end
  end
  
  def send_all_unsent_to_westmead
    supplier_id = 3
    unsent_emails_to_westmead = Email.find(:all, :conditions => {:user_id => current_user.id, :supplier_id => supplier_id, :sent => 0})
    unsent_emails_to_westmead.each do |e|
      email_to_westmead = FormsMailer.send_form_to_westmead(e.from, e.to, e.cc, e.subject, e.content, e.attachments, ("data/email_attachments/" + current_user.id.to_s))
      if (email_to_westmead.deliver)
        e.sent = 1
        e.save
      end
    end
    
    redirect_to :protocol => "https://", :action => "westmead_comms_form"  # production
    #redirect_to :action => "westmead_comms_form"   # on local machine
  end
  
  def delete_email
    Email.delete(params[:email_id])
    
    if (params[:supplier_id].to_i == 1)
      redirect_to :protocol => "https://", :action => "sava_comms_form"  # production
      #redirect_to :action => "sava_comms_form"   # on local machine
    elsif (params[:supplier_id].to_i == 2)
      redirect_to :protocol => "https://", :action => "medex_comms_form"  # production
      #redirect_to :action => "medex_comms_form"   # on local machine
    else #(params[:supplier_id].to_i == 3)
      redirect_to :protocol => "https://", :action => "westmead_comms_form"  # production
      #redirect_to :action => "westmead_comms_form"   # on local machine
    end
  end
  
  def attach_files
    if (params[:attached_file_1] != nil || params[:attached_file_2] != nil || params[:attached_file_3] != nil)
      attached_files = [params[:attached_file_1], params[:attached_file_2], params[:attached_file_3]] - [""] - [nil]
      file_names = []
      logger.info(attached_files.inspect)
    
      attached_files.each do |afile|
        file_name = afile.original_filename
        file_names << file_name
        # Write the file to public/email_attachments/<user_id>
        File.open(Rails.root.join('data', 'email_attachments', current_user.id.to_s, file_name), 'wb') do |file|
          file.write(afile.read)
        end
      end
    
      if (file_names != [])
        e = Email.find(params[:email_id])
      
        if (e != nil)
          e.attachments = file_names.join(",")
          e.save
        end
      end
    end
    
    if (params[:commit] == "Save Attachments")
      if (params[:supplier_id].to_i == 1)
        redirect_to :protocol => "https://", :action => "sava_comms_form", :email_id => params[:email_id]  # production
        #redirect_to :action => "sava_comms_form", :email_id => params[:email_id]   # on local machine
      elsif (params[:supplier_id].to_i == 2)
        redirect_to :protocol => "https://", :action => "medex_comms_form", :email_id => params[:email_id]  # production
        #redirect_to :action => "medex_comms_form", :email_id => params[:email_id]   # on local machine
      else #(params[:supplier_id].to_i == 3)
        redirect_to :protocol => "https://", :action => "westmead_comms_form", :email_id => params[:email_id]  # production
        #redirect_to :action => "westmead_comms_form", :email_id => params[:email_id]   # on local machine
      end
    end
  end
  
  def delete_attachment
    if (params[:email_id] != nil)
      e = Email.find(params[:email_id].to_i)
      logger.info([params[:file_name]].inspect)
      e.attachments = (e.attachments.split(",") - [params[:file_name]]).join(",")
      e.save
    end
    
    if (params[:supplier_id].to_i == 1)
      redirect_to :protocol => "https://", :action => "sava_comms_form", :email_id => params[:email_id]  # production
      #redirect_to :action => "sava_comms_form", :email_id => params[:email_id]   # on local machine
    elsif (params[:supplier_id].to_i == 2)
      redirect_to :protocol => "https://", :action => "medex_comms_form", :email_id => params[:email_id]  # production
      #redirect_to :action => "medex_comms_form", :email_id => params[:email_id]   # on local machine
    else #(params[:supplier_id].to_i == 3)
      redirect_to :protocol => "https://", :action => "westmead_comms_form", :email_id => params[:email_id]  # production
      #redirect_to :action => "westmead_comms_form", :email_id => params[:email_id]   # on local machine
    end
  end
  
  
  
end
