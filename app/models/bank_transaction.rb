#encoding: utf-8
class BankTransaction < ActiveRecord::Base
  belongs_to :site

  simple_audit do |bt_record|
    {
        :id => bt_record.id,
        :sequence_id => bt_record.sequence_id,
        :bank_date => bt_record.bank_date,
        :transaction_amt => bt_record.transaction_amt,
        :balance => bt_record.balance,
        :customer_notes => bt_record.customer_notes,
        :filename => bt_record.filename,
        :order_ids => bt_record.order_ids,
        :site_id => bt_record.site_id,
        :status_change_date => bt_record.status_change_date,
        :staff_comments => bt_record.staff_comments,
        :bank_id => bt_record.bank_id,
        :site_id => (Site.current_site.id rescue nil),
        :username_method => User.current
    }
  end
  
  self.per_page = 100
  
  class << self
    def import_payment(bank_id, updfile)
      begin
        @payment_amt_details = []
        raise "You have not selected a file." if updfile.nil?
        file, filename = updfile, updfile.original_filename
        raise "Invalid file format" if !Constant::XLS_CONTENT_TYPES.include?(file.content_type.to_s)

        fpath = Rails.root.join(Constant::DIR_PAYMENTS)
        FileUtils.mkdir_p(fpath) if !File.exists? fpath
        fpath = fpath.join(filename)
        File.open((fpath), 'wb'){|f| f.write(file.read)}

        bank = Bank.find(bank_id) rescue nil
        site_id = bank.site_id
        bank_id = bank.id
        IscOrder.reconfigure_db(site_id)
        Site.current_site = Site.find(site_id.to_i)        
        csv_file = File.read(Rails.root.join(Constant::DIR_PAYMENTS, filename), :encoding => "Shift_JIS")
        csv = CSV.parse(csv_file)

        # Read in data from csv file
        first_row = true
        csv.each do |row|
          bank_trxn_temp = nil

          if !first_row
            bank_trxn_temp = BankTransaction.insert_transaction(row[0].to_date, row[1].to_f, row[2].to_f, convert_multi_to_single_byte_alpha_num(row[3].to_s), filename, nil, site_id, bank_id)
            @payment_amt_details << convert_multi_to_single_byte_alpha_num(row[1].to_s).to_f << convert_multi_to_single_byte_alpha_num(row[3].to_s) << ((bank_trxn_temp != nil)? bank_trxn_temp.id : nil)
          else
            first_row = false
          end
        end

        @possible_order_ids = {}
        @possible_first_last_names = {}
        @possible_orders = {}
        @status_updated = {}
        i = 1
        all_unpaid_orders = IscOrder.find(:all, :conditions => { :ordstatus => [1,7,8] }, :order => :ordbillemail)      
        
        # loop through array of payment records.
        while (i < @payment_amt_details.count)
          IscOrder.reconfigure_db(site_id)

          payment_amt = @payment_amt_details[i - 1].to_f
          payment_details = @payment_amt_details[i]
          
          @possible_order_ids[i] = []
          @possible_first_last_names[i] = payment_details
          @possible_orders[i] = []
          @status_updated[i] = []

          if (payment_amt > 0)  # if payment amount < 0, the transaction is not a payment
            if site_id == Constant::HB_ID
              first_order_id_index = (payment_details =~ /\d{7}/)
              order_id_length = 7
            elsif site_id == Constant::KX_ID
              if payment_details.to_i.to_s.first == Constant::KX_PREFIXID.to_s
                first_order_id_index = (payment_details =~ /\d{8}/)
                order_id_length = Constant::ORDID_LENGTH
              elsif payment_details.to_i.to_s.first == Constant::WS_PREFIXID
                first_order_id_index = (payment_details =~ /\d{6}/)
                order_id_length = Constant::YHVH_ORDID_LENGTH
              else
                first_order_id_index = (payment_details =~ /\d{7}/)  #PROBABLY CHANGE WHEN YHVH.JP CHANGE THEIR ORDERID
                order_id_length = Constant::YHVH_ORDID_LENGTH + 1
              end
            elsif site_id == Constant::PKY_ID
                first_order_id_index = (payment_details =~ /\d{9}/)
                order_id_length = Constant::MAGENTO_ORDID_LENGTH
            else
              first_order_id_index = (payment_details =~ /\d{8}/)
              order_id_length = Constant::ORDID_LENGTH
            end

            temp_payment_details = payment_details
            
            # If there are order id(s) in the payment details, put the possible order_ids in @possible_order_ids
            while (first_order_id_index != nil)
              if site_id == 16
                temp_order_id = temp_payment_details.to_i
                if temp_order_id.to_s.first == "9" && temp_order_id.to_s.length == 6
                  IscOrder.reconfigure_db(17) #site WebShark
                  temp_order_id = temp_order_id.to_s.rjust(8, '9')
                  tmp_order_id = temp_payment_details[first_order_id_index..(first_order_id_index + (6 - 1))].to_i
                  @possible_order_ids[i] << tmp_order_id.to_s.rjust(8, '9')
                elsif temp_order_id.to_s.length == 7
                  IscOrder.reconfigure_db(17) #site WebShark
                  temp_order_id = temp_order_id.to_s.rjust(8, '9')
                  tmp_order_id = temp_payment_details[first_order_id_index..(first_order_id_index + (7 - 1))].to_i
                  @possible_order_ids[i] << tmp_order_id.to_s.rjust(8, '9')
                else
                  @possible_order_ids[i] << temp_payment_details[first_order_id_index..(first_order_id_index + (order_id_length - 1))].to_i
                end
                @possible_order_ids[i] << temp_payment_details[first_order_id_index..(first_order_id_index + (order_id_length - 1))].to_i
              end
              
              temp_payment_details = temp_payment_details[(first_order_id_index + order_id_length)..(temp_payment_details.length - 1)]
              first_order_id_index = (site_id != 12)? (temp_payment_details =~ /\d{8}/) : (temp_payment_details =~ /\d{7}/)
            end
            
            @possible_order_ids[i] = (@possible_order_ids[i] != nil)? @possible_order_ids[i].uniq : []
            @possible_first_last_names[i] = payment_details
            
            # Get possible customer names from the payment details 
            @possible_order_ids[i].each do |oid|
              @possible_first_last_names[i] = @possible_first_last_names[i].delete(oid.to_s) 
            end
          
            @possible_first_last_names[i] = @possible_first_last_names[i].to_s.gsub(/\s+|-|−|_|,|#/, "")
            
            # If at least one order id exists in the payment details
            if (@possible_order_ids[i] != [])
              @possible_orders[i] = IscOrder.find_by_sql("SELECT * FROM isc_orders WHERE orderid IN (" + @possible_order_ids[i].join(",") + ")")
              bank_trxn = (@payment_amt_details[i+1] != nil)? BankTransaction.find(@payment_amt_details[i+1]) : nil
              
              if (bank_trxn != nil && @possible_order_ids[i] != [])
                bank_trxn.order_ids = @possible_order_ids[i].join(",")
              end
              temp_payment_amt = payment_amt
              
              ords_total_inc_tax = 0
              if (@possible_orders.count > 1)
                ords_total_inc_tax = @possible_orders[i].collect { |po| po.total_inc_tax.to_i }.inject(:+)
              end
              
              # loop through the possible orders
              @possible_orders[i].each do |ord|
                ord.reload
                ord_total_inc_tax = (ords_total_inc_tax == 0)? ord.total_inc_tax.to_i : ords_total_inc_tax
                
                if [1,7,8,4,5,6].include?(ord.ordstatus)
                  if (temp_payment_amt == ord_total_inc_tax && bank_trxn != nil)
                    ord.update_attribute(:ordstatus, 11)
                    IscOrder.status_update_email(ord, site_id)
                    if (ord.save)
                      bank_trxn.status_change_date = Time.now.strftime("%Y-%m-%d %H:%M:%S")
                    end
                    @status_updated[i] << ("Order #" + ord.orderid.to_s + ", Amount: " + ord.total_inc_tax.to_i.to_s + " ==> " + ((ord.save == true)? "Updated." : "Not Updated."))
                  elsif (temp_payment_amt > ord_total_inc_tax)
                    if (bank_trxn != nil)
                      bank_trxn.order_ids = nil
                      bank_trxn.save
                    end
                    @status_updated[i] << ("Order #" + ord.orderid.to_s + ", Amount: " + ord.total_inc_tax.to_i.to_s + " ==> Not Updated - *Paid in excess.")
                  else  # else if payment amount / remainder payment amount < total incl. tax, append order details & error message
                    if (bank_trxn != nil)
                      bank_trxn.order_ids = ""
                      bank_trxn.save
                    end
                    @status_updated[i] << ("Order #" + ord.orderid.to_s + ", Amount: " + ord.total_inc_tax.to_i.to_s + " ==> Not Updated - *Not fully Paid")
                  end
                else
                  if (temp_payment_amt != ord_total_inc_tax && bank_trxn != nil)
                    bank_trxn.order_ids = nil
                    bank_trxn.save
                  end
                  @status_updated[i] << ("Order #" + ord.orderid.to_s + ", Amount: " + ord.total_inc_tax.to_i.to_s + " ==> Not Updated - Current Order Status: " + ord.ordstatus.to_s + ((ord.isc_order_status != nil)? (" " + ord.isc_order_status.statusdesc) : ""))
                end
              end
              
              bank_trxn.save unless bank_trxn.nil?
            else
              unpaid_orders_with_same_name_amt = all_unpaid_orders.select { |o| convert_multi_to_single_byte_alpha_num(BankTransaction.hira_to_kata(o.ordbillfirstname)).gsub(/\s+|-|−|_|,|#| /, "") == @possible_first_last_names[i].gsub(/ /,"") && o.total_inc_tax == payment_amt }
              
              if (unpaid_orders_with_same_name_amt.count == 0)
                unpaid_orders_with_same_name = all_unpaid_orders.select { |o| convert_multi_to_single_byte_alpha_num(BankTransaction.hira_to_kata(o.ordbillfirstname)).gsub(/\s+|-|−|_|,|#| /, "") == @possible_first_last_names[i].gsub(/ /,"") }
                unpaid_orders_with_same_total =  all_unpaid_orders.select { |o| o.total_inc_tax == payment_amt }
                @possible_orders[i] += (unpaid_orders_with_same_name + unpaid_orders_with_same_total).uniq

              elsif (unpaid_orders_with_same_name_amt.count == 1)


                amt = unpaid_orders_with_same_name_amt[0].total_inc_tax.to_f
                bank_trxn = (@payment_amt_details[i+1] != nil)? BankTransaction.find(@payment_amt_details[i+1]) : nil
                if (payment_amt == unpaid_orders_with_same_name_amt[0].total_inc_tax && bank_trxn != nil)
                  logger.info("Unpaid Orders With Same Name:" + unpaid_orders_with_same_name_amt[0].inspect) 
                  unpaid_orders_with_same_name_amt[0].update_attribute(:ordstatus, 11)

                  bank_trxn = (@payment_amt_details[i+1] != nil)? BankTransaction.find(@payment_amt_details[i+1]) : nil
                  

                  logger.info("unpaid_orders_with_same_name_amt: " + unpaid_orders_with_same_name_amt.inspect)
                  bank_trxn.order_ids = unpaid_orders_with_same_name_amt[0].orderid #unpaid_orders_with_same_name_amt[0].join(",")
                
                  if (unpaid_orders_with_same_name_amt[0].save)
                    bank_trxn.status_change_date = Time.now.strftime("%Y-%m-%d %H:%M:%S") # change the status_change date time to the current date time
                  end
                
                  @status_updated[i] << ("Order #" + unpaid_orders_with_same_name_amt[0].orderid.to_s + ", Amount: " + unpaid_orders_with_same_name_amt[0].total_inc_tax.to_i.to_s + " ==> " + ((unpaid_orders_with_same_name_amt[0].save == true)? "Updated." : "Not Updated."))
                  
                  bank_trxn.save

                elsif (payment_amt > unpaid_orders_with_same_name_amt[0].total_inc_tax)

                  if (bank_trxn != nil)
                    bank_trxn.order_ids = nil
                    bank_trxn.save
                  end
                  @status_updated[i] << ("Order #" + unpaid_orders_with_same_name_amt[0].orderid.to_s + ", Amount: " + unpaid_orders_with_same_name_amt[0].total_inc_tax.to_i.to_s + " ==> Not Updated - *Paid in excess.")
                else  # else if payment amount / remainder payment amount < total incl. tax, append order details & error message
                  if (bank_trxn != nil)
                    bank_trxn.order_ids = ""
                    bank_trxn.save
                  end
                  @status_updated[i] << ("Order #" + unpaid_orders_with_same_name_amt[0].orderid.to_s + ", Amount: " + unpaid_orders_with_same_name_amt[0].total_inc_tax.to_i.to_s + " ==> Not Updated - **Not fully Paid")
                end
              else

                if (payment_amt == unpaid_orders_with_same_name_amt[0].total_inc_tax && bank_trxn != nil)
                  latest_order = unpaid_orders_with_same_name_amt[0]
                  other_matching_oids = []
                
                  unpaid_orders_with_same_name_amt.each do |o|
                    other_matching_oids << o.orderid
                    if (latest_order.orderid < o.orderid)
                      latest_order = o
                    end
                  end
                
                  latest_order.ordstatus = 11

                  bank_trxn = (@payment_amt_details[i+1] != nil)? BankTransaction.find(@payment_amt_details[i+1]) : nil
                
                  bank_trxn.order_ids = latest_order.orderid # latest_order.join(",")
                
                  if (latest_order.save)
                    IscOrder.status_update_email(latest_order, site_id)
                    bank_trxn.status_change_date = Time.now.strftime("%Y-%m-%d %H:%M:%S") # change the status_change date time to the current date time
                  end
                  
                  other_matching_oids = other_matching_oids - [latest_order.orderid]
                  @status_updated[i] << ("Latest Order #" + latest_order.orderid.to_s + ", Amount: " + latest_order.total_inc_tax.to_i.to_s + " ==> " + ((latest_order.save == true)? "Updated." : "Not Updated.") + ((other_matching_oids != [])? (" Other matching orders include: " + other_matching_oids.join(",")) : ""))
                  bank_trxn.save

                elsif (payment_amt > unpaid_orders_with_same_name_amt[0].total_inc_tax) 

                  if (bank_trxn != nil)
                    bank_trxn.order_ids = nil
                    bank_trxn.save
                  end
                  @status_updated[i] << ("Order #" + unpaid_orders_with_same_name_amt[0].orderid.to_s + ", Amount: " + unpaid_orders_with_same_name_amt[0].total_inc_tax.to_i.to_s + " ==> Not Updated - *Paid in excess.")
                else  # else if payment amount / remainder payment amount < total incl. tax, append order details & error message
                  if (bank_trxn != nil)
                    bank_trxn.order_ids = ""
                    bank_trxn.save
                  end
                  @status_updated[i] << ("Order #" + unpaid_orders_with_same_name_amt[0].orderid.to_s + ", Amount: " + unpaid_orders_with_same_name_amt[0].total_inc_tax.to_i.to_s + " ==> Not Updated - ***Not fully Paid")
                end
              end
            end
          end
        
          i += 3
        end

        # Delete the file from data/payments/
        File.delete("#{RAILS_ROOT}/data/payments/" + filename)

        result = {
          :payment_amt_details => @payment_amt_details,
          :possible_order_ids => @possible_order_ids,
          :status_updated => @status_updated,
          :possible_orders => @possible_orders,
          :possible_first_last_names => @possible_first_last_names,
        }
        
        return result
      rescue Exception => e
        return "Error: #{e.message}"
      end
    end
    
    def get_data_to_export(yr_mon, bank_id)
      begin
        yr_mth   = yr_mon
        bank     = Bank.find(bank_id)
        site_id  = bank.site_id
        csv_data = []
        
        bank_trxns = BankTransaction.get_bank_transactions(yr_mth, bank.id, site_id)
        IscOrder.reconfigure_db(site_id)
        
        bank_trxns.each do |trxn|
          prev_trxn = bank_trxns.select { |bt| bt.sequence_id == (trxn.sequence_id - 1) }
          balance_tally = (prev_trxn != [])? (trxn.balance.to_f - (prev_trxn[0].balance.to_f + trxn.transaction_amt.to_f)) : "Previous Balance Not Found"
          payment_tally = nil
  
          if (!trxn.order_ids.nil? && !trxn.order_ids.blank?)
            total_amt = 0.0
            orders = IscOrder.select("total_inc_tax").where("orderid IN (?)", trxn.order_ids.split(","))            
            orders.each{ |ord| total_amt += ord.total_inc_tax.to_f }
            payment_tally = (total_amt - trxn.transaction_amt.to_f)
            payment_tally = (payment_tally != 0.0)? (payment_tally * -1) : payment_tally
          end
  
          if trxn.site.sitecode == Constant::KX_CODE
            channel = trxn.other_sales_channel_id.nil? ? "" : "Webshark"
            csv_data << [trxn.order_ids, trxn.bank_date, trxn.transaction_amt, trxn.balance, trxn.customer_notes, balance_tally.to_f, ((payment_tally.nil?) ? "" : "#{payment_tally.to_f}"), trxn.staff_comments, trxn.filename, (trxn.status_change_date.strftime("%Y-%m-%d") rescue ""), channel ]
          else
            csv_data << [trxn.order_ids, trxn.bank_date, trxn.transaction_amt, trxn.balance, trxn.customer_notes, balance_tally.to_f, ((payment_tally.nil?) ? "" : "#{payment_tally.to_f}"), trxn.staff_comments, trxn.filename, (trxn.status_change_date.strftime("%Y-%m-%d") rescue "") ]
          end
        end
        
        return csv_data
      rescue Exception => e
        return "Error: #{e.message}"
      end
    end
    
    def mark_as_paid(btid, order_id, site_id)
      begin
        bank_trxn = BankTransaction.find(btid)

        unless bank_trxn.nil?
          order_ids = (!bank_trxn.order_ids.nil?) ? ((bank_trxn.order_ids.split(",") << order_id).uniq).join(",") : order_id.to_s
          bank_trxn.update_fields(:order_ids => order_ids, :status_change_date => Time.current.strftime("%Y-%m-%d %H:%M:%S"))
        end

        IscOrder.reconfigure_db(site_id)
        order = IscOrder.find(order_id)
        order.mark_as_paid(site_id)
      
        return true
      rescue Exception => e
        Rails.logger.info(e.message)
        Rails.logger.info("Error: #{e.message}")
        return nil
      end
    end
    
    def update_status_change_date(bank_transaction_id = nil)
      trxn = self.find(bank_transaction_id)
      trxn.status_change_date = Time.current.strftime("%Y-%m-%d_%H-%M-%S")
      return trxn
    end
    
    def update_other_sales_channel_id(bank_transaction_id = nil, other_sales_channel_id = nil)
      trxn = self.find(bank_transaction_id)
      trxn.other_sales_channel_id = other_sales_channel_id
      trxn.save
      return trxn
    end
        
    def create_csv(csv_data = [], bank_id, yr_mth)
      begin
        bank = Bank.find(bank_id)
        workbook = Spreadsheet::Workbook.new
        sheet1 = workbook.create_worksheet name: "Sheet1"
        site = bank.site
        headers = [ "Order ID(s)", "Transaction Date", "Transaction Amount", "Balance", "Customer Notes",
                    "Balance Tally", "Payment Tally", "Staff Comment(s)", "Filename", "Status Updated On" ]

        unless site.nil?
          headers.push "Other Sales Channel" if site.sitecode.to_s == "KX"
        end

        sheet1.row(0).replace headers    
        #setting column width
        sheet1.column(0).width = 10
        sheet1.column(1).width = 10
        sheet1.column(2).width = 15
        sheet1.column(3).width = 15
        sheet1.column(4).width = 25
        sheet1.column(5).width = 17
        sheet1.column(6).width = 17
        sheet1.column(7).width = 18
        sheet1.column(8).width = 30
        sheet1.column(9).width = 20

        unless site.nil?
          if site.sitecode.to_s == "KX"
            sheet1.column(10).width = 10
          end
        end
    
        csv_data.each_with_index do |data, indx|
          row_id = indx.to_i + 1
          sheet1.row(row_id).replace data 
        end
    
        filename   =  yr_mth.to_s + "_#{bank.bank_name}_#{bank.site.sitecode}" + "_" + Time.current.strftime("%Y-%m-%d_%H-%M-%S") + ".xls"
        file_path  = Constant::DIR_BANK_TRXNS + "/" + filename
        folderpath = Rails.root.join(Constant::DIR_BANK_TRXNS)
        FileUtils.mkdir_p(folderpath) unless File.exists? folderpath      
        workbook.write(file_path)

        return filename
      rescue Exception => e
        Rails.logger.info("#{e.message}")
        nil
      end
    end
    
    def get_bank_transactions(yr_mth = nil, bank_id = nil, site_id = nil)                                                           
      yr_mth = (Time.current - 1.month).strftime("%Y-%m").to_s if yr_mth.nil?                                                                                                                                 
      transactions = includes(:site).where("bank_date >= ? AND bank_date <= ? AND bank_id = ? AND site_id = ?", "#{yr_mth}-01", "#{yr_mth}-31", bank_id, site_id).order("sequence_id ASC")
      return transactions                                
    end

    #shorten params
    def insert_transaction(bank_date = nil, transaction_amt = 0.0, balance = 0.0, customer_notes = nil, filename = nil, order_ids = nil, site_id = nil, bank_id = nil)
      new_trxn = nil
      trxn     = self.find(:all, :conditions => { :bank_date => bank_date, :transaction_amt => transaction_amt, :balance => balance, :customer_notes => customer_notes, :site_id => site_id } )

      if (trxn == [])
        trxns_for_mth = BankTransaction.get_bank_transactions(bank_date.strftime("%Y-%m").to_s, bank_id, site_id)
        sequence_id = 0
        
        if (trxns_for_mth != [])
          trxns_for_mth.each do |t|
            if (t.sequence_id > sequence_id)
              sequence_id = t.sequence_id
            end
          end
          
          sequence_id = sequence_id + 1
        end
        
        new_trxn = self.new(:sequence_id => sequence_id, :bank_date => bank_date, :transaction_amt => transaction_amt, :balance => balance, :customer_notes => customer_notes, :filename => filename, :order_ids => order_ids, :site_id => site_id, :bank_id => bank_id)
        
        new_trxn.save
      else
        logger.info("Trxn Already Exists. Found: " + trxn.inspect)
      end
      
      return new_trxn
    end
    
    def by_year_month
      trans = select("DATE_FORMAT(bank_date, '%Y-%m') as yr_month").order("bank_date DESC")
      trans.map(&:yr_month).uniq
    end

    def get_transactions(yr_month, bank_id, site_id, options = {})
      page    = options[:page].blank? ? 1 : options[:page]
      perpage = options[:perpage].blank? ? self.per_page : options[:perpage].to_i
      
      yr_month = yr_month || "#{Time.current.year}-#{Time.current.month}"
      result = BankTransaction.select("*, DATE_FORMAT(bank_date, '%Y-%m') as yr_month").
        where("bank_date >= ? AND bank_date <= ? AND bank_id = ? AND site_id = ?", "#{yr_month}-01", "#{yr_month}-31", bank_id, site_id).
        page(page).per_page(perpage)
      result = result.order("sequence_id ASC")
    end

    def get_total_ws_bt_payments_collected(date = Time.current.strftime("%Y-%m-01"))
      trxns = BankTransaction.where("site_id = 16 AND other_sales_channel_id = 1 AND bank_date >= '" + date + "' AND bank_date < '" + (date.to_date + 1.month).strftime("%Y-%m-01") + "'")
      payment_amts = trxns.collect { |trxn| trxn.transaction_amt }
      return payment_amts.inject(0.0,:+)
    end
        
    ############ Katakana / Hiragana conversion ##############
    def NotKanaCharacters
      not_kana_chars = ['〜', '＄', '＃', '＠', '！', '％', '＾', '＆', '＊', '（', '）','＿', 'ー', '＋','＝', '？', '＞', '＜', '、', '。', '／', '』', '『', '「', '」', '｀']
      return not_kana_chars
    end
  
    def HiraganaCharacters
      hira_chars = [' ', '　', '々', 'っ', 'ょ', 'ゃ', 'ゅ', 'あ', 'い', 'う', 'え', 'お', 'か', 'き', 'く', 'け', 'こ', 'さ', 'し', 'す', 'せ', 'そ', 'た', 'ち', 'つ', 'て', 'と', 
                    'な', 'に', 'ぬ', 'ね', 'の', 'は', 'ひ', 'ふ', 'へ', 'ほ', 'ま', 'み', 'む', 'め', 'も', 'や', 'ゆ', 'よ', 'ら', 'り', 'る', 'れ', 'ろ', 'わ', 'ゐ', 'ゑ', 'を', 
                    'ん', 'が', 'ぎ', 'ぐ', 'げ', 'ご', 'ざ', 'じ', 'ず', 'ぜ', 'ぞ', 'だ', 'ぢ', 'づ', 'で', 'ど', 'ば', 'び', 'ぶ', 'べ', 'ぼ', 'ぱ', 'ぴ', 'ぷ', 'ぺ', 'ぽ', 'ヶ']
      return hira_chars
    end
  
    def KatakanaCharacters
      kata_chars = ['ョ', 'ャ', 'ュ', 'ア', 'イ', 'ウ', 'エ', 'オ', 'カ', 'キ', 'ク', 'ケ', 'コ', 'サ', 'シ', 'ス', 'セ', 'ソ', 'タ', 'チ', 'ツ', 'テ', 'ト', 'ナ', 'ニ', 'ヌ', 'ネ', 
                    'ノ', 'ハ', 'ヒ', 'フ', 'ヘ', 'ホ', 'マ', 'ミ', 'ム', 'メ', 'モ', 'ヤ', 'ユ', 'ヨ', 'ラ', 'リ', 'ル', 'レ', 'ロ', 'ワ', 'ゐ', 'ゑ', 'ヲ', 'ン', 'ガ', 'ギ', 'グ', 
                    'ゲ', 'ゴ', 'ザ', 'ジ', 'ズ', 'ゼ', 'ゾ', 'ダ', 'ヅ', 'ヂ', 'ズ', 'デ', 'ド', 'バ', 'ビ', 'ブ', 'ベ', 'ボ', 'パ', 'ピ', 'プ', 'ペ', 'ポ']
      return kata_chars
    end
  
    def Kata2hiraH
      kata2hira_hash = {"ア"=>"あ", "イ"=>"い", "ウ"=>"う", "エ"=>"え", "オ"=>"お", "カ"=>"か", "キ"=>"き", "ク"=>"く", "ケ"=>"け", "コ"=>"こ", "ガ"=>"が", "ギ"=>"ぎ", "グ"=>"ぐ", 
                        "ゲ"=>"げ", "ゴ"=>"ご", "サ"=>"さ", "シ"=>"し", "ス"=>"す", "セ"=>"せ", "ソ"=>"そ", "ザ"=>"ざ", "ジ"=>"じ", "ズ"=>"ず", "ゼ"=>"ぜ", "ゾ"=>"ぞ", "タ"=>"た", "チ"=>"ち", "ツ"=>"つ", 
                        "テ"=>"て", "ト"=>"と", "ダ"=>"だ", "ヂ"=>"ぢ", "ヅ"=>"づ", "デ"=>"で", "ド"=>"ど", "ナ"=>"な", "ニ"=>"に", "ヌ"=>"ぬ", "ネ"=>"ね", "ノ"=>"の", "ハ"=>"は", "ヒ"=>"ひ", "フ"=>"ふ", 
                        "ヘ"=>"へ", "ホ"=>"ほ", "バ"=>"ば", "ビ"=>"び", "ブ"=>"ぶ", "ベ"=>"べ", "ボ"=>"ぼ", "パ"=>"ぱ", "ピ"=>"ぴ", "プ"=>"ぷ", "ペ"=>"ぺ", "ポ"=>"ぽ", "マ"=>"ま", "ミ"=>"み", "ム"=>"む", 
                        "メ"=>"め", "モ"=>"も", "ヤ"=>"や", "ユ"=>"ゆ", "ヨ"=>"よ", "ラ"=>"ら", "リ"=>"り", "ル"=>"る", "レ"=>"れ", "ロ"=>"ろ", "ワ"=>"わ", "ヰ"=>"ゐ", "ヱ"=>"ゑ", "ヲ"=>"を", "ン"=>"ん", 
                        "ァ"=>"ぁ", "ィ"=>"ぃ", "ゥ"=>"ぅ", "ェ"=>"ぇ", "ォ"=>"ぉ", "ッ"=>"っ", "ャ"=>"ゃ", "ュ"=>"ゅ", "ョ"=>"ょ", "ヴ"=>"う゛", "ヵ"=>"か", "ヶ"=>"が", "ヮ"=>"ゎ"}
      return kata2hira_hash
    end
  
    def Hira2kataH
      hira2kata_hash = {}
      self.Kata2hiraH.each_pair{|k,v| hira2kata_hash[v]=k}; 
      hira2kata_hash["か"]="カ";
      hira2kata_hash["が"]="ガ"
      return hira2kata_hash
    end

    def normalize_double_n(str)
      return str.gsub(/n\'(?=[^aiueoyn]|$)/, "n")
    end
  
    def kata_to_hira(str) # **
      kata2hira_h = self.Kata2hiraH
      s=""; str.each_char{|c| s+=( kata2hira_h.key?(c) ? kata2hira_h[c] : c )}
      s = self.normalize_double_n(s)
      return s
    end

    def hira_to_kata(str)
      hira2kata_h = self.Hira2kataH
      s=""; str.each_char{|c|if(hira2kata_h.key?(c))then s+=hira2kata_h[c];else s+=c; end}
      return s
    end
  
    def kana2kana(str1)
      result = []
      str2 = self.hira_to_kata(str1)
      str3 = self.kata_to_hira(str1)
      result << str1
      result << str2 if str2.length > 0 and str1 !=str2
      result << str3 if str3.length > 0 and str2 !=str3 and str3 != str1    
      return result
    end
    
  end
  
  #instance methods
  
  def set_orderid(order_id)
    begin
      order_id = order_id.to_s.strip
      self.update_attribute(:order_ids, order_id)
      site_id = self.site_id
      
      if order_id.to_s.length <= Constant::ORDID_LENGTH #8
        if self.site_id == Constant::KX_ID
          if order_id.to_s.first.to_i == BK_ID || ( order_id.to_s.length == (Constant::ORDID_LENGTH - 1) && order_id.to_s.first.to_i != Constant::WS_PREFIXID )
            site_id = Constant::WS_ID
          end
        end
      else
        site_id = Site.find_by_sitecode(Constant::PKY_CODE).id
      end

      IscOrder.reconfigure_db(site_id)
      order = IscOrder.find(order_id.to_i) rescue nil

      unless order.nil?
        orig_status = order.ordstatus
        invalid_status = IscOrder::STATUS['Unpaid'] + IscOrder::STATUS['Pending'] + IscOrder::STATUS['Cancelled']
        if invalid_status.include?(order.ordstatus.to_i)
          order.update_attribute(:ordstatus, IscOrder::STATUS['Paid'].first)
          self.update_attribute(:status_change_date, Time.current)
          if orig_status != order.ordstatus
            IscOrder.status_update_email(order, self.site_id)
          end
        end
      end
      
      self
    rescue Exception => e
      Rails.logger.info("#{e.message}")
      RedMailer.delay(:queue => "others").notifier("Error: BankTransaction.set_orderid(#{order_id} - #{e.message}")
      nil
    end
  end
  
  def update_fields(args={})
    args.keys.each do |key|
      args.delete(key) if !self.attributes.has_key? "#{key}"
    end

    self.update_attributes(args)
  end
end
