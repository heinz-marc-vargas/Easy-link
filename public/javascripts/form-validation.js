$(document).ready(function() {
	//* validation for user
	user_validation.add();
	//* validation for site
	//site_validation.add();
});

//* validation
user_validation = {
	add: function() {
		var user_validator = $('.user-form').validate({
			onkeyup: false,
			errorClass: 'error',
			validClass: 'valid',
			highlight: function(element) {
				$(element).closest('div').addClass("f_error");
			},
			unhighlight: function(element) {
				$(element).closest('div').removeClass("f_error");
			},
      rules: {
				firstname: { required: true, minlength: 3 },
				lastname: { required: true, minlength: 3 },
				your_message: { required: true, minlength: 20 },
				
				days: { required: true, minlength: 2 },
				gender: { required: true },
				address2: { required: true, minlength: 5 },
				city: { required: true, minlength: 2 },
				state: { required: true, minlength: 3 }
			},
			invalidHandler: function(form, validator) {
				$.sticky("There are some errors. Please corect them and submit again.", {autoclose : 5000, position: "top-right", type: "st-error" });
			},
			errorPlacement: function(error, element) {
				// Set positioning based on the elements position in the form
				var elem = $(element);
				
				// Check we have a valid error message
				if(!error.is(':empty')) {
					if( (elem.is(':checkbox')) || (elem.is(':radio')) ) {
						// Apply the tooltip only if it isn't valid
						elem.filter(':not(.valid)').parent('label').parent('div').find('.error_placement').qtip({
							overwrite: false,
							content: error,
							position: {
								my: 'left bottom',
								at: 'center right',
								viewport: $(window),
								adjust: {
									x: 6
								}
							},
							show: {
								event: false,
								ready: true
							},
							hide: false,
							style: {
								classes: 'ui-tooltip-red ui-tooltip-rounded' // Make it red... the classic error colour!
							}
						})
						// If we have a tooltip on this element already, just update its content
						.qtip('option', 'content.text', error);
					} else {
						// Apply the tooltip only if it isn't valid
						elem.filter(':not(.valid)').qtip({
							overwrite: false,
							content: error,
							position: {
								my: 'bottom left',
								at: 'top right',
								viewport: $(window),
                                  adjust: { x: -8, y: 6 }
							},
							show: {
								event: false,
								ready: true
							},
							hide: false,
							style: {
								classes: 'ui-tooltip-red ui-tooltip-rounded' // Make it red... the classic error colour!
							}
						})
						// If we have a tooltip on this element already, just update its content
						.qtip('option', 'content.text', error);
					};
                      
				}
				// If the error is empty, remove the qTip
				else {
					if( (elem.is(':checkbox')) || (elem.is(':radio')) ) {
						elem.parent('label').parent('div').find('.error_placement').qtip('destroy');
					} else {
						elem.qtip('destroy');
					}
				}
			},
			success: $.noop // Odd workaround for errorPlacement not firing!
		})
	}
};
