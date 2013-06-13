$(document).ready(function() {

  $(".mage_select_supplier").live('change', function() {
    op_id = $(this).attr("data-id");
    supp_id = $(this).val();
    $("#change_supplier_loader-" + op_id).show();
    $.get("/magento_orders/change_supplier.js?op_id=" + op_id + "&supplier_id=" + supp_id)
  });
	

  $(".mage-edit-address").live('click', function() {
    id = $(this).attr('data-id');
    $("#mage_edit_address_loader-" + id).show();
    $.get("/magento_orders/" + id + "/ajax_edit_shipping.js");
  });

});
