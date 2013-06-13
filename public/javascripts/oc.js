var OC = {

	clear_ajax:function() {
		abort_ajax_requests();
	},
	
	getUsers: function() {
		OC.clear_ajax();
		$("#loader").show();
		$.ajax({
			url: "/users.js",
			type: "get"
		});
	},
	
	editUser: function(id) {
		OC.clear_ajax();
		$("#loader").show();
		$.ajax({
			url: "/users/" + id + "/edit.js",
			type: "get"
		});
	},

	getSites: function() {
		OC.clear_ajax();
		$("#loader").show();
		$.ajax({
			url: "/sites.js",
			type: "get"
		});
	},
	
	editSite: function(id) {
		OC.clear_ajax();
		$("#loader").show();
		$.ajax({
			url: "/sites/" + id + "/edit.js",
			type: "get"
		});
	},
	
	clearForms: function() {
		$("#loader").hide();
		$("#adduser-form").remove();
		$("#edituser-form").remove();
		$("#addsite-form").remove();
		$("#editsite-form").remove();
		$("#addproduct-form").remove();
		$("#editproduct-form").remove();
		$("#addsupplier-form").remove();
		$("#insertproduct-form").remove();
		$("#editsupplier-form").remove();
		$("#addcombi-form").remove();
		$("#editshopproduct-form").remove();
		$("#editcartproduct-form").remove();
	},
	
	getProducts: function() {
		OC.clear_ajax();
		$("#loader").show();
		$.ajax({
			url: "/products.js",
			type: "get"
		});
	},
	
	getShopProducts: function() {
		OC.clear_ajax();
		$("#loader").show();
		$.ajax({
			url: "/products/shop.js",
			type: "get"
		});
	},
	
	
	editProduct: function(id) {
		OC.clear_ajax();
		$("#loader").show();
		$.ajax({
			url: "/products/" + id + "/edit.js",
			type: "get"
		});
	},
	
	getCartProducts: function() {
		OC.clear_ajax();
    $("#loader").show();
    $.ajax({
      url: "/products/cart_middle_layer.js",
      type: "get"
    });
  },
	
	getSuppliers: function() {
		OC.clear_ajax();
		$("#loader").show();
		$.ajax({
			url: "/suppliers.js",
			type: "get"
		});
	},
	
	editSupplier: function(id) {
		OC.clear_ajax();
		$("#loader").show();
		$.ajax({
			url: "/suppliers/" + id + "/edit.js",
			type: "get"
		});
	},
	
	getOrders: function(status) {
		OC.clear_ajax();
		$("#loader").show();
		$.ajax({
			url: "/orders.js?status=" + status,
			type: "get"
		});
	},
	
	updateOrdersTotals: function() {
		OC.clear_ajax();
		$("#loader_totals").show();
		$.ajax({
			url: "/orders/update_totals.js",
			type: "get"
		});
	},
	
	showOrderSummary: function() {
		OC.clear_ajax();
		$("#loader").show();
		var params = "";
		if ($(".order-summary-search-form #date").length > 0) {
			params += "date=" + $(".order-summary-search-form #date").val();
		}
		
		if ($(".order-summary-search-form #site_id").length > 0) {
			params += "&site_id=" + $(".order-summary-search-form #site_id").val();
		}
		
		$.ajax({
			url: "/orders/order_summary.js?" + params,
			type: "get"
		});
	},

  checkQtyDuplicate: function() {
		OC.clear_ajax();
		$("#loader").show();
		$.ajax({
			url: "/orders/check_qty_duplicate.js",
			type: "get"
		});
		return true;    
  },
  
	checkOrderDuplicate: function() {
		OC.clear_ajax();
		$("#loader").show();
		$.ajax({
			url: "/orders/check_duplicate.js",
			type: "get"
		});
		return true;		
	},
	
	showOrderSpreadsheets: function() {
		OC.clear_ajax();
		$("#loader").show();
		$.ajax({
			url: "/orders/spreadsheets.js",
			type: "get"
		});
		return true;
	},
	
	generateSheet: function(site_id, date, dis) {
    $(dis).text("Generating...");
    $(dis).attr("disabled", "disabled");
    
		OC.clear_ajax();
		$("#loader").show();
		params = { site_id: site_id, date: date }
		$.ajax({
			url: "/orders/generate_spreadsheet.js?",
			data: params,
			type: "post"
		});		
	},

	generateMagentoSheet: function(site_id, date) {
		OC.clear_ajax();
		$("#loader").show();
		params = { site_id: site_id, date: date }
		$.ajax({
			url: "/orders/generate_spreadsheet_mage.js?",
			data: params,
			type: "post"
		});		
	},
	
	showImports: function() {
		OC.clear_ajax();
		$("#loader").show();
		$.ajax({
			url: "/orders/imports.js?",
			type: "get"
		});
	},
	
	showShippingNotifications: function() {
		OC.clear_ajax();
		$("#loader").show();
		$.ajax({
			url: "/shippings.js?",
			type: "get"
		});
	},
	
	resendNotification: function() {
		var ans = confirm("Are you sure?");
		if (ans) {
			$("#loader").show();
			return false;
		}else{
			return false;
		}
	},
	
	showReOrder: function() {
		OC.clear_ajax();
		$("#loader").show();
		$.ajax({
			url: "/orders/reorders.js?",
			type: "get"
		});
	},
	
	importStocks: function() {
		OC.clear_ajax();
		$("#loader").show();
		$.ajax({
			url: "/products/stocks.js?",
			type: "get"
		});
	},
	
	importThresholds: function() {
		OC.clear_ajax();
		$("#loader").show();
		$.ajax({
			url: "/products/thresholds.js?",
			type: "get"
		});
	},
	
	showProductCommentForm: function(sku, area) {
		OC.clear_ajax();
		$(this).hide();
		
		$.ajax({
			url: "/products/show_note_form.js?sku=" + sku + "&area=" + area,
			type: "get"
		});
	},
	
	showCommentForm: function(id, klass) {
		OC.clear_ajax();
		$(this).hide();
		
		$.ajax({
			url: "/products/show_comment_form.js?id=" + id + "&klass=" + klass,
			type: "get"
		});
	},
	
	exportBankTransaction: function(yr_month, bank_id) {
		$("#exportBankTransaction").show();
		
		$.ajax({
		  url: "/banktransactions/export",
		  data: "yr_month=" + yr_month + "&bank_id=" + bank_id,
		  success: function(data) {
		  	console.log(data);
		  	$("#exportBankTransaction").hide();

				if (data.filename) {
	            window.location.href = "/banktransactions/export_download?file=" + data.filename;
	        }
	        else {
	            alert(data.errormsg);
	        }
		  }
		});
	}

}
