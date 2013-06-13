class UsersDatatable
  delegate :image_tag, :can?, :raw, :edit_user_path, :render, :params, :h, :link_to, :number_to_currency, :user_path, to: :@view

  def initialize(view)
    @view = view
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: User.count,
      iTotalDisplayRecords: users.total_entries,
      aaData: data
    }
  end

private

  def data
    users.map do |user|
      [
        user_link(user),
        h(user.fullname),
        h(user.created_at.strftime("%b %d, %Y")),
        h(user.mobileno),
        actions(user)
      ]
    end
  end

  def users
    @users ||= fetch_users
  end

  def user_link(user)
    if can? :update, User
      link_to(user.email, edit_user_path(user, :format => :js), :remote => true, :class => "pop_over fit-content", "data-content" => "#{image_tag(user.avatar.url(:thumb), :size => "50x50")}", "data-placement" => "top", "data-original-title" => user.fullname)     
    else
      user.email
    end    
  end
  
  def actions(user)
    actions = ""
    if can? :update, User
      actions = "<a href=\"#\" class=\"edit-user\" data-id=\"#{user.id}\" title=\"Edit\"><i class=\"splashy-document_letter_edit\"></i></a>"
      actions += "<span class='user-status'>"
      actions += render(:partial => "/users/status", :locals => { :user => user }) 
      actions += "</span>"
    end
    if can? :destroy, User
      actions += link_to(raw("<i class='icon-adt_trash'></i>"), user_path(user), :confirm => "Are you sure you want to delete this record?", :method => :delete, :remote => true, :title => "Delete")
    end
    actions.to_s
  end
  
  def fetch_users
    users = User.order("#{sort_column} #{sort_direction}")
    users = users.page(page).per_page(per_page)

    if params[:sSearch].present?
      users = users.where("email like :search or first_name like :search or last_name like :search or mobileno like :search", search: "%#{params[:sSearch]}%")
    end
    users
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : Constant::PERPAGE
  end

  def sort_column
    columns = %w[email first_name created_at mobileno]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end