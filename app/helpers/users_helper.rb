module UsersHelper

  def checked_radio(user, role)
    puts "#{user.usertype}==#{role.to_s}"
    if user.new_record?
      case role.to_sym
      when :services
        return "checked"
      else
        return ''
      end
    else
      return "checked" if user.usertype == role.to_s
      return ''
    end
  end
    
end