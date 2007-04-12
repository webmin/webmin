#!/usr/local/bin/perl
# Delete a bunch of printers at once

require './lpadmin-lib.pl';
&ReadParse();
&error_setup($text{'delete_err'});
@d = split(/\0/, $in{'d'});
@d || &error($text{'delete_enone'});

# Delete the printers, locally, from ACLs and from the cluster
foreach $d (@d) {
	$access{'delete'} && &can_edit_printer($d) ||
		&error($text{'save_eedit'});
	$prn = &get_printer($d);
	$info = &log_info($prn);
	&delete_printer_and_driver($prn);
	&delete_from_acls($d);

	# delete from cluster
	@slaveerrs = &delete_on_cluster($prn);
	if (@slaveerrs) {
		&error(&text('save_errdelslave',
		     "<p>".join("<br>", map { "$_->[0]->{'host'} : $_->[1]" }
					    @slaveerrs)));
		}
	}
&system_logged("$config{'apply_cmd'} >/dev/null 2>&1 </dev/null")
	if ($config{'apply_cmd'});
&webmin_log("delete", "printers", scalar(@d));

&redirect("");


