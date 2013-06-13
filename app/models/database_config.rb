require "base64"

class DatabaseConfig < ActiveRecord::Base
  belongs_to :site
  
  def encode(password = "")
    return Base64.encode64("#{password}")
  end
  
  def password=(password)
    self[:password] = encode(password)
  end
  
  def decode
    self[:password] = Base64.decode64("#{self[:password]}")
  end
  
  def decrypted_attr
    original_password = self[:password]
    decode
    tempVar = attributes.clone
    self[:password] = original_password
    
    return tempVar
  end

end