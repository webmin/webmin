#!/usr/local/bin/perl
# Delete or refresh multiple monitors at once

require './status-lib.pl';
&ReadParse();
$in{'d'} || &error($text{'deletes_enone'});
@d = split(/\0/, $in{'d'});

if ($in{'delete'}) {
	# Deleting
	$access{'edit'} || &error($text{'mon_ecannot'});
	foreach $d (@d) {
		$serv = &get_service($d);
		$serv || &error($text{'deletes_egone'});
		push(@dels, $serv);
		}
	foreach $serv (@dels) {
		&delete_service($serv);
		}
	&webmin_log("deletes", undef, scalar(@dels));
	&redirect("");
	}
else {
	# Refreshing
	&ui_print_unbuffered_header(undef, $text{'refresh_title'}, "");

	print &text('refresh_doing2', scalar(@d)),"<br>\n";
	&foreign_require("cron", "cron-lib.pl");
	&cron::create_wrapper($cron_cmd, $module_name, "monitor.pl");
	$ids = join(" ", map { quotemeta($_) } @d);
	&clean_environment();
	&system_logged("$cron_cmd --force $ids >/dev/null 2>&1 </dev/null");
	&reset_environment();
	&webmin_log("refresh");
	print $text{'refresh_done'},"<p>\n";
	&ui_print_footer("", $text{'index_return'});
	}
