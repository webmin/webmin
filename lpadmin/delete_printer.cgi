#!/usr/local/bin/perl
# delete_printer.cgi
# Delete an existing printer

require './lpadmin-lib.pl';
&ReadParse();
$access{'delete'} && &can_edit_printer($in{'name'}) ||
	&error($text{'save_eedit'});
$prn = &get_printer($in{'name'});
$info = &log_info($prn);
&delete_printer_and_driver($prn);
&system_logged("$config{'apply_cmd'} >/dev/null 2>&1 </dev/null")
	if ($config{'apply_cmd'});
&delete_from_acls($in{'name'});
&webmin_log("delete", "printer", $prn->{'name'}, $info);

# delete from cluster
@slaveerrs = &delete_on_cluster($prn);
if (@slaveerrs) {
	&error(&text('save_errdelslave',
	     "<p>".join("<br>", map { "$_->[0]->{'host'} : $_->[1]" }
				    @slaveerrs)));
	}

&redirect("");

