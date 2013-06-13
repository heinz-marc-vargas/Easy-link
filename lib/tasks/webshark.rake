require 'rest_client'

namespace :webshark do

  #parameters: from_date string, 2012-12-24
  #            to_date string,  2012-12-28
  #            user_id integer
  #            site_id integer 
  desc "Download Order.csv || Order Product csv"
  task :download_order_csv => :environment do
    require 'csv'
    puts "Downloading Orders.csv file..."
    user_id = ENV['user_id']
    site_id = ENV['site_id']

    unless ENV['from_date'].nil?
      from_date = ENV['from_date'] 
    else
      if Time.current.beginning_of_week.to_date == Time.current.to_date
        from_date = (Time.current - 3.days).to_date
      else
        from_date = (Time.current - 1.day).to_date
      end
    end 
    
    unless ENV['to_date'].nil?
      to_date = ENV['to_date'] 
    else
      to_date = Time.current.to_date
    end 

    year, month, day = from_date.to_s.split("-")
    year2, month2, day2 = to_date.to_s.split("-")    
    
    options = {
        :fixation => 0, :still_fixation => 1, :cancel => 0, :reservation => 0,
        :year => year, :month => month, :day=> day,
        :year2 => year2, :month2 => month2, :day2 => day2,
        :H_ID => CONFIG[:webshark_id], :H_PW => CONFIG[:webshark_pwd],
        :csv_type => Constant::WEBSHARK_FILETYPES['Orders'], :act => 'csv'
      }
      
    response = RestClient.post(CONFIG[:webshark_url], options)
    time = "#{Time.current.hour}-#{Time.current.min}-#{Time.current.sec}"    

    filename = "orders_" + from_date.to_s + "_" + time + '.csv'
    FileUtils.mkpath Rails.root.join('data','ws_order_data') if !File.exists?(Rails.root.join('data','ws_order_data'))
    File.open(Rails.root.join('data','ws_order_data',filename), 'wb'){|f| f << response.to_str}
    Rails.logger.info("Finish downloading file: #{filename} ...")
    
    if File.exist? Rails.root.join('data','ws_order_data',filename)
      #downloading the orders_products.csv file
      options[:csv_type] = Constant::WEBSHARK_FILETYPES['Order Products']
      response = RestClient.post(CONFIG[:webshark_url], options)
      op_filename = "orders_products_" + from_date.to_s + "_" + time + '.csv'
      File.open(Rails.root.join('data','ws_order_data',op_filename), 'wb'){|f| f << response.to_str}
      Rails.logger.info("Finish downloading file: #{op_filename} ...")
      
      file = WebsharkFile.create_new({:filename => filename, :user_id => user_id, :site_id => site_id})

      begin
        lines = File.read(Rails.root.join('data', 'ws_order_data', filename), :encoding => "Shift_JIS")
        csv = CSV.parse(lines)

        csv.each do |row|
          Rails.logger.info(row.inspect)
          orderid = row[0].to_i
          next if orderid == 0

        end
        
      rescue Exception => e
        file.logs = file.logs.to_s + "\n#{e.message.to_s}"
        file.save        
      end
      
    end

    
    puts "Done..."
    
    puts IscOrder.get_ws_otids(from_date, to_date, filename)
  end
  
end



