module ProductsHelper
  
  def show_supplier_name(product, suppliers)
    return "(#{suppliers[product.supplier_id].first.company_name})" rescue ''
  end
end