#!/usr/local/bin/perl
# Create all needed tables

require './acl-lib.pl';
$access{'pass'} || &error($text{'sql_ecannot'});
&get_miniserv_config(\%miniserv);
&ReadParse();
&error_setup($text{'make_err'});

$dbh = &connect_userdb($in{'userdb'});
ref($dbh) || &error($dbh);

&ui_print_unbuffered_header(undef, $text{'make_title'}, "");

# Create the tables
foreach $sql (&userdb_table_sql($in{'userdb'})) {
	print &text('make_exec', "<tt>".&html_escape($sql)."</tt>"),"<br>\n";
	$cmd = $dbh->prepare($sql);
	if (!$cmd || !$cmd->execute()) {
		print &text('make_failed', &html_escape($dbh->errstr)),"<p>\n";
		}
	else {
		print $text{'make_done'},"<p>\n";
		}
	}

# Check again if OK
$err = &validate_userdb($in{'userdb'}, 0);
if ($err) {
	print "<b>",&text('make_still', $err),"</b><p>\n";
	}
else {
	&lock_file($ENV{'MINISERV_CONFIG'});
	$miniserv{'userdb'} = $in{'userdb'};
	$miniserv{'userdb_addto'} = $in{'addto'};
	&put_miniserv_config(\%miniserv);
	&unlock_file($ENV{'MINISERV_CONFIG'});
	&reload_miniserv();
	}

&ui_print_footer("", $text{'index_return'});

