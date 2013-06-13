class IscOrdersDatatable
  delegate :params, :h, :link_to, :number_to_currency, to: :@view

  def initialize(view)
    @view = view
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: IscOrder.count,
      iTotalDisplayRecords: orders.total_entries,
      aaData: data
    }
  end

private

  def data
    orders.map do |order|
      [
        link_to(order.orderid, "#"),
        "11",
        "22",
        "33"
      ]
    end
  end

  def orders
    @orders ||= fetch_orders
  end

  def fetch_orders
    orders = IscOrder.order("#{sort_column} #{sort_direction}")
    orders = orders.page(page).per_page(per_page)
    if params[:sSearch].present?
      orders = orders.where("orderid like :search", search: "%#{params[:sSearch]}%")
    end
    orders
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : Constant::PERPAGE
  end

  def sort_column
    columns = %w[orderid orderid]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end