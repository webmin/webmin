#!/usr/local/bin/perl
# Create all needed tables

require './acl-lib.pl';
$access{'pass'} || &error($text{'sql_ecannot'});
&get_miniserv_config(\%miniserv);
&ReadParse();
&error_setup($text{'make_err'});

$str = $miniserv{'userdb'};
$dbh = &connect_userdb($str);
ref($dbh) || &error($dbh);

&ui_print_unbuffered_header(undef, $text{'make_title'}, "");

foreach $sql (&userdb_table_sql($str)) {
	print &text('make_exec', "<tt>".&html_escape($sql)."</tt>"),"<br>\n";
	$cmd = $dbh->prepare($sql);
	if (!$cmd || !$cmd->execute()) {
		print &text('make_failed', &html_escape($dbh->errstr)),"<p>\n";
		}
	else {
		print $text{'make_done'},"<p>\n";
		}
	}

&ui_print_footer("", $text{'index_return'});

