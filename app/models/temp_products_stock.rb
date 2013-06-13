class TempProductsStock < ActiveRecord::Base
  belongs_to :supplier
  

  class << self
    def create_new(stock = {})
      create!(stock)
    end
  end
end
