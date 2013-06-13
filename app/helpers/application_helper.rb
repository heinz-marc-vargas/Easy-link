#encoding: utf-8
module ApplicationHelper
  def format_date(date, format='yyyymmdd')
    return nil if date.nil?
    
    case format
    when 'yyyy-mm-dd'
      date.strftime("%Y-%m-%d")
    when 'MdY'
      date.strftime("%b %d, %Y")
    when "MdY-time"
      date.strftime("%b %d, %Y %H:%M:%S")
    else
      date.strftime("%Y%m%d")    
    end
  end
  
  def span_loader(name, show='hide', options = {})
    html = "<span style=\"left !important;position: absolute; right: 30px;\" class=\"ajax_loader #{show}\" id=\"#{name}\">"
    html += image_tag("/img/ajax_loader.gif")
    html += "</span>"
    return raw(html)
  end

  def span_loader2(name, show='hide', options = {})
    html = "<span class=\"ajax_loader #{show}\" id=\"#{name}\">"
    html += image_tag("/images/loading-small.gif")
    html += "</span>"
    return raw(html)
  end
  
  def show_current_lang
    case session[:lang].to_s
    when "en"
      return "flag-us"
    when "ja"
      return "flag-jp"
    else
      return "flag-us"
    end 
  end

  def convert_multi_to_single_byte_alpha_num(str = "")
    str = str.to_s
    str = str.gsub(/[〜－]/, "-")
    str = str.gsub(/~/, "-")

    return ActiveSupport::Multibyte::Chars.new(str).normalize(:kc)
  end
  
  def space(n=2)
    html = "&nbsp;" * n
    return raw(html)
  end
  def space_pipe(n=2)
    space = "&nbsp;" * n
    html = space + "|" + space
    return raw(html)
  end
end
