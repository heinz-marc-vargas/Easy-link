class Asset < ActiveRecord::Base
  belongs_to :assetable, :polymorphic => true

  serialize :order_ids
  validates :name, :presence => true
  validates :site_id, :presence => true

  class << self
    def order_spreadsheets(site_id, limit=20)
      limit ||= 20
      where("site_id = ?", site_id).
      limit(limit).
      order("created_at DESC")
    end    
  end
  #end of class methods
  
  def get_csvfile
    require 'csv'
    allrows = []
    file    = Constant::XLS_PATH + "#{self.name}"
    csvfile = file.to_s.gsub(".xls", ".csv")

    Spreadsheet.client_encoding = 'UTF-8'
    xls = Spreadsheet.open file
    sheet = xls.worksheet 0

    skip_rows = 0
    orderid_index = 0

    sheet.each skip_rows do |row|
      orderid = row[0].to_s
      str = []
      
      unless orderid.blank?
        row.each do |r|
          str << r
        end
      end
      
      allrows << str unless str.empty?
    end

    CSV.open(csvfile, "wb") do |csv|
      allrows.each do |row|
        csv << row
      end
    end    

    csvfile
  end
  
  def get_columns_from_file
    order_rows = []
    file = Rails.root.join(Constant::DIR_XLS, self.name)
    return order_rows if !File.exists? file
    
    Spreadsheet.client_encoding = 'UTF-8'
    xls = Spreadsheet.open file
    sheet = xls.worksheet 0
    skip_rows = 1 

    sheet.each skip_rows do |row|
      next if row[0].to_s.strip.blank?
      order_rows << "#{row[0]}***#{row[1]}***#{row[2]}***#{row[3]}"
    end
    
    order_rows
  end

  
  def get_orders_from_file
    order_rows = []
    file = Rails.root.join(Constant::DIR_XLS, self.name)
    return order_rows if !File.exists? file
    
    Spreadsheet.client_encoding = 'UTF-8'
    xls = Spreadsheet.open file
    sheet = xls.worksheet 0
    skip_rows = 1 

    sheet.each skip_rows do |row|
      next if row[0].to_s.strip.blank?
      order_rows << "#{row[0]}***#{row[9].upcase}***#{row[12]}"
    end
    
    order_rows
  end

end
