class ProductsDatatable
  delegate :can?, :raw, :edit_product_path, :params, :h, :link_to, :number_to_currency, :product_path, to: :@view

  def initialize(view)
    @view = view
  end

  def as_json(options = {})
    {
      sEcho: params[:sEcho].to_i,
      iTotalRecords: Product.count,
      iTotalDisplayRecords: products.total_entries,
      aaData: data
    }
  end

private

  def data
    products.map do |product|
      [
        link_to(product.name, edit_product_path(product), :remote => true, :title => "Edit"),
        h(product.ext_product_id),
        h(product.supplier.company_name),
        product.stock,
        product.restock_threshold,
        actions(product)
      ]
    end
  end

  def products
    @products ||= fetch_products
  end

  def actions(product)
    actions = ""
    if can? :update, product
      actions =  link_to(raw("<i class='splashy-document_letter_edit'></i>"), edit_product_path(product), :remote => true, :title => "Edit")
    end
    actions += raw("&nbsp;")
    if can? :destroy, product
      actions += link_to(raw("<i class='icon-adt_trash'></i>"), product_path(product), :confirm => "Are you sure you want to delete this record?", :method => :delete, :remote => true, :title => "Delete")
    end
    actions.to_s
  end
  
  def fetch_products
    products = Product.order("#{sort_column} #{sort_direction}")
    products = products.page(page).per_page(per_page)

    if params[:sSearch].present?
      products = products.where("name like :search or ext_product_id like :search or id like :search", search: "%#{params[:sSearch]}%")
    end
    
    if params[:sSearch_2].present?
      products = products.where("supplier_id = ?", params[:sSearch_2])
    end
    products
  end

  def page
    params[:iDisplayStart].to_i/per_page + 1
  end

  def per_page
    params[:iDisplayLength].to_i > 0 ? params[:iDisplayLength].to_i : Constant::PERPAGE
  end

  def sort_column
    columns = %w[name ext_product_id supplier_id stock restock_threshold]
    columns[params[:iSortCol_0].to_i]
  end

  def sort_direction
    params[:sSortDir_0] == "desc" ? "desc" : "asc"
  end
end