var Application = {
  load_content: function(path, params){
    $('.main_content').fadeOut("fast");
    $('.main_content').load(path, params);
    $('.main_content').fadeIn("fast");
    $("#loader").hide();
  },

  render_content: function(content){
    $('.main_content').html(content).fadeIn('fast');
    $("#loader").hide();
  }
};

var ajax_requests = Array();

function abort_ajax_requests(){
	if (ajax_requests.length > 0){
		console.log("aborting ajax_requests...");
		
	  for(var i=0; i<ajax_requests.length; i++) {
	    ajax_requests[i].abort();
	  }
	  ajax_requests = [];
	}
}

function abort_rails_requests(){
	if (rails_requests.length > 0){
		console.log("aborting rails_requests...");
	
	  for(var i=0; i<rails_requests.length; i++) {
	  	rails_requests[i].abort();
	  }
	  rails_requests = [];
	}
}

$(document).ready(function() {

	$("body").click(function(){
		$(".popover").remove();
	});
	
	$(".perpage-bank-transactions").live("change", function() {
		if ($(this).val() != "") {
			$("#loader").show();
			$(".bank-transaction-search-form #per_page").val($(this).val());
			$(".bank-transaction-search-form").submit();
		}
	});	


	$(".bottom_pagination ul li a").live("click", function() {
		$("#loader").show();
	})

	$(".top_pagination ul li a").live("click", function() {
		$("#loader").show();
	})
	
  $(".pagination a").live("click", function() {
    //$(".pagination").html("Page is loading...");
    $.get(this.href, null, null, "script");
    return false;
  });
  
  $(".sidebar-menu").click(function(){
  	$("#loader").show();
  });
  

	$("#").click('change', function() {
	  agel > 13  || age < 100
	})
	
  $("#logout").click(function() {
    jQuery.ajax({
      url: "/users/logout",
      type: "delete",
      success: function(data) {
        window.location.href = "/";
      }
    });
  });
  
  $("#btn-cancel").live('click', function() {
  	OC.clearForms();
  })


	// orders

	$(".mg-show-order-details").live('click', function() {
		id = $(this).attr('data-id');
		$("#order-loader-" + id).show();
		$("#order-row-details-" + id).hide();
		OC.clear_ajax();
		//$("#order-row-details-" + id).slideDown();				
		$.ajax({
			url: "/magento_orders/" + id + "/orderdetails.js",
			type: "get"
		});
	});
	$(".mg-show-billing-details").live('click', function() {
		id = $(this).attr('data-id');
		$("#order-loader-" + id).show();
		$("#order-row-details-" + id).hide();	
		OC.clear_ajax();
					
		$.ajax({
			url: "/magento_orders/" + id + "/billingdetails.js",
			type: "get"
		});
	});
	$(".mg-show-shipping-details").live('click', function() {
		id = $(this).attr('data-id');
		$("#order-loader-" + id).show();
		$("#order-row-details-" + id).hide();		
		OC.clear_ajax();
				
		$.ajax({
			url: "/magento_orders/" + id + "/shippingdetails.js",
			type: "get"
		});
	});	
	
	$(".show-order-details").live('click', function() {
		id = $(this).attr('data-id');
		$("#order-loader-" + id).show();
		$("#order-row-details-" + id).hide();
		OC.clear_ajax();

		//$("#order-row-details-" + id).slideDown();				
		$.ajax({
			url: "/orders/" + id + "/orderdetails.js",
			type: "get"
		});
	});
	$(".show-billing-details").live('click', function() {
		id = $(this).attr('data-id');
		$("#order-loader-" + id).show();
		$("#order-row-details-" + id).hide();	
		OC.clear_ajax();
					
		$.ajax({
			url: "/orders/" + id + "/billingdetails.js",
			type: "get"
		});
	});
	$(".show-shipping-details").live('click', function() {
		id = $(this).attr('data-id');
		$("#order-loader-" + id).show();
		$("#order-row-details-" + id).hide();	
		OC.clear_ajax();
					
		$.ajax({
			url: "/orders/" + id + "/shippingdetails.js",
			type: "get"
		});
	});
	
	$(".close-details").live('click', function() {
		id = $(this).attr("data-id");

		$("#order-content-" + id).slideUp(function() {
			console.log("done");
			$("#order-row-details-"+id).hide();
		});
	});
	$(".edit-shipping-details").live("click", function() {
		id = $(this).attr('data-id');
		$("#shipping" + id).show();
	});

	$(".cancel-btn-shipping").live('click', function() {
		id = $(this).attr('data-id');
		$("#shipping" + id).show();
		OC.clear_ajax();

		if ($(this).attr('mage')) {
			$.get("/magento_orders/" + id + "/shippingdetails.js");
		} else {
			$.get("/orders/" + id + "/shippingdetails.js");
		}		
	});
	
	$('#shippingdate').datepicker();	

	$(".split_qty").live('change', function() {
		id = $(this).attr("id");
		val = $(this).val();
		if (val == "--") {
			var ans = confirm("This will remove existing split orders. Do you still want to continue?");
			if (!ans)				
				return false;
		}
		
		$("#split_qty_loader-" + id).show();
		$.get("/orders/" + id + "/split_by_qty.js?val=" + val);			
	});

	$(".select_supplier").live('change', function() {
		op_id = $(this).attr("data-id");
		supp_id = $(this).val();
		$("#change_supplier_loader-" + op_id).show();
		$.get("/orders/change_supplier.js?op_id=" + op_id + "&supplier_id=" + supp_id)
	});

	$(".edit-address").live('click', function() {
		id = $(this).attr('data-id');

		$("#edit_address_loader-" + id).show();
		$.get("/orders/" + id + "/ajax_edit_shipping.js");
	});

	$(".close-shipping-address").live('click', function() {
		$("#temp-content").empty();
	});	
	
	$(".btn_send_to_queue").live('click', function() {
		
		$("#form-queue").empty();
		rows = $("#accordion2").clone();
		rows.addClass("hide");
		$("#form-queue").append(rows.html());

		if ($("#form-queue input[type=checkbox]:checked").length ==0) {
			alert("Please select an order.");
			return false;
		}
		
    $(this).text("Sending...");
    $(this).attr("disabled", "disabled");
		$("#loader_queue").show();
		$("#form-queue").submit();
	});

	$("#chk-order-all").live('change', function() {
		if ( $("#chk-order-all").is(":checked")) {
			rows = $("#accordion2").clone();
			rows.addClass('hide');
			$("#form-queue").append(rows.html());
			$("#modalPreviewSupplierData input[type=checkbox]").attr('checked', 'checked');
		}else{
			$("#form-queue").empty();
			$("#modalPreviewSupplierData input[type=checkbox]").removeAttr('checked');
		}
	});

	$(".order-proc-row").live('click', function() {
		order_id = $(this).val();
		if ($(this).is(":checked")) {
			$(this).attr('checked', 'checked');
			$("#table-" + order_id + " input[type='checkbox']").attr('checked', 'checked');
		}else{
			$(this).removeAttr('checked');
			$("#table-" + order_id + " input[type='checkbox']").removeAttr('checked');			
		}
	});
		
	$(".order-row-chk").live('click', function() {
		order_id = $(this).val();
		if ($(this).is(":checked")) {
			$(this).attr('checked', 'checked');
			$("#table-" + order_id + " input[type='checkbox']").attr('checked', 'checked');
		}else{
			$(this).removeAttr('checked');
			$("#table-" + order_id + " input[type='checkbox']").removeAttr('checked');			
		}
	});
	
	$(".breadcrumbs li a").live('click', function() {
		$("#loader").show();
	});

	
	
	

	// orders end
  
  // user forms
  $("#button-adduser").click(function() {
  	$("#adduser-form").show();
  });
  
  $(".edit-user").live('click', function() {
  	id = $(this).attr("data-id");
  	OC.editUser(id);
  })
  
  $("#button-adduser-cancel").live('click', function() {
  	$("#adduser-form").slideUp(200).delay(800).fadeOut();
  	$("#adduser-form").remove();
  	//just making sure
  	$("#edituser-form").slideUp(200).delay(800).fadeOut();
  	$("#edituser-form").remove();
  });
  
  // user forms ends here

  // sites forms
  $("#button-addsite").click(function() {
  	$("#addsite-form").show();
  });
  
  $(".edit-site").live('click', function() {
  	id = $(this).attr("data-id");
  	OC.editSite(id);
  })
  
  $("#button-addsite-cancel").live('click', function() {
  	$("#addsite-form").slideUp(200).delay(800).fadeOut();
  	$("#addsite-form").remove();
  	//just making sure
  	$("#editsite-form").slideUp(200).delay(800).fadeOut();
  	$("#editsite-form").remove();
  });
  
  // sites forms ends here


  //products
  $(".shop-product-suppleir-list").live("change", function(){
  	sprod_id = $(this).attr("data-id");
  	site_id = $(this).attr("site-id");
  	supplier_id = $(this).val();
		$.post("/products/" + sprod_id + "/set_default_supplier.js?supplier_id=" + supplier_id + "&site_id=" + site_id);
  });
  
  $("#button-addproduct-cancel").live('click', function() {
  	$("#addproduct-form").slideUp(200).delay(800).fadeOut();
  	$("#addproduct-form").remove();
  	//just making sure
  	$("#editproduct-form").slideUp(200).delay(800).fadeOut();
  	$("#editproduct-form").remove();
  });

  $("#button-insertproduct-cancel").live('click', function() {
    OC.clearForms();
    $("#loader").show();
    $.get("/products/shop.js");
  });
  
  $("#add_shop_products").live('click', function() {
  	if ($(".product_sites:checked").length == 0) {
  		alert("Please select a site first");
  		return false;
  	} 
  	if ($("#add_shop_products").is(":checked"))
  	  $(".set-default-supplier").show();
  	else
  		$(".set-default-supplier").hide();
  });
	$(".add_image").live('click', function() {
		row = $(".row-template").clone();
		row.removeClass('hide');
		row.show();
		
		$("#new-combi-rows").append(row.html());
	});
	$(".remove-combi-row").live('click', function() {
		$(this).closest('.control-group').remove();
	})
	$("#combi-form").validate();
	$("#show-note-form").live('click', function() {
		area = ''
		if ($(this).attr("data-area"))
			area = $(this).attr("data-area");
		console.log(area);		
		sku = $(this).attr("data-id");
		$(this).hide();
		$("#" + sku).show();
		OC.showProductCommentForm(sku, area);
	})
	
	$("#show-comment-form").live('click', function() {
		klass = ''
		if ($(this).attr("data-area"))
			klass = $(this).attr("data-area");
		
		id = $(this).attr("data-id");
		$(this).hide();
		$("#" + id).show();
		OC.showCommentForm(id, klass);
	});

  
  //suppliers
  $("#button-addsupplier-cancel").live('click', function() {
  	$("#addsupplier-form").slideUp(200).delay(800).fadeOut();
  	$("#addsupplier-form").remove();
  	//just making sure
  	$("#editsupplier-form").slideUp(200).delay(800).fadeOut();
  	$("#editsupplier-form").remove();
  });  


	$(".bank_transaction_orderid").live("change", function(){
		btid = $(this).attr("data-id");
		order_id = $(this).val();
		$("#orderid_btid_" + btid).show();
		OC.clear_ajax();		
		$.post("/banktransactions/set_orderid.js?btid=" + btid + "&order_id=" + order_id);
	})  

	//bank transactions
	$(".sales_channel_select").live("change", function(){
		var ans = confirm("Are you sure you want to continue?");
		if (ans) {
			channel = $(this).val();
			id = $(this).attr("data-id");
			OC.clear_ajax();
			$.post("/banktransactions/update_sales_channel?id=" + id + "&channel_id=" + channel);
		}else{
			return false;
		}
	})

     
});
