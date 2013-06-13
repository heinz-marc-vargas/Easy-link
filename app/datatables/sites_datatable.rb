class SitesDatatable
  delegate :current_user, :can?, :raw, :edit_site_path, :params, :h, :link_to, :number_to_currency, :site_path, to: :@view
  
  require 'net/http' #used to send XML data via HTTP Post
  require 'net/https'
  
  def initialize(view)
    @view = view
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: Site.count,
      iTotalDisplayRecords: sites.total_entries,
      aaData: data
    }
  end

private

  def data
    sites.map do |site|
      [
        site_link(site),
        h(site.sitecode),
        h(site.site_url),
        h(site.hostname),
        (site.sitecode[site.sitecode.length - 1] != 'C' && site.cart_type != 2)? "<iframe style='width:120px; height:20px;' scrolling='no' frameborder='0' src='http://genkipet.smarterandfaster.com/check_alive_site.php?s_url=" + site.site_url.split("http://")[1] + "'></iframe>" : "- Cloned & Unchecked -",
        (site.sitecode[site.sitecode.length - 1] != 'C')? Site.check_sites_are_alive(site.site_url) : "- Cloned & Unchecked -",
        actions(site)
      ]
    end
  end

  def sites
    @sites ||= fetch_sites
  end

  def site_link(site)
    if can? :update, site
      link_to(site.sitename, edit_site_path(site, :format => :js), :remote => true)
    else
      site.sitename
    end    
  end
  
  def actions(site)
    actions = ""
    if can? :update, site
      actions += "<a href=\"#\" class=\"edit-site\" data-id=\"#{site.id}\" title=\"Edit\"><i class=\"splashy-document_letter_edit\"></i></a> &nbsp;"
    end
    if can? :destroy, site
      actions += link_to(raw("<i class='icon-adt_trash'></i>"), site_path(site), :confirm => "Are you sure you want to delete this record?", :method => :delete, :remote => true, :title => "Delete")
    end
    actions.to_s
  end
  
  def fetch_sites
    sites = current_user.sites.order("#{sort_column} #{sort_direction}")
    sites = sites.page(page).per_page(per_page)
    if params[:sSearch].present?
      sites = sites.where("sitename like :search or site_url like :search or hostname like :search or sitecode like :search", search: "%#{params[:sSearch]}%")
    end
    sites
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : Constant::PERPAGE
  end

  def sort_column
    columns = %w[sitename sitecode site_url hostname]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end
