/* ***** Audit Log ************************ */
$(".show_audit_detail").click(function () {
  var $aid_model_id = $(this).attr("id").split('_');
  var $audit_object_row = $("#audit-object-row-" + $aid_model_id[0]);
  $audit_object_row.toggle("slow");
s});