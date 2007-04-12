#!/usr/local/bin/perl
# build.cgi
# Build a new sendmail.cf, after first confirming the changes

require './sendmail-lib.pl';
require './features-lib.pl';
$features_access || &error($text{'features_ecannot'});
&ReadParse();
$cmd = "cd $config{'sendmail_features'}/m4 ; m4 $config{'sendmail_features'}/m4/cf.m4 $config{'sendmail_mc'}";

if ($in{'confirm'}) {
	# Replace sendmail.cf with new version
	&lock_file($config{'sendmail_cf'});
	system("$cmd 2>/dev/null >$config{'sendmail_cf'} </dev/null");
	&unlock_file($config{'sendmail_cf'});
	&restart_sendmail();
	&webmin_log("build");
	&redirect("");
	}
else {
	# Just show user what would be done
	&ui_print_header(undef, $text{'build_title'}, "");

	if (!&has_command("m4")) {
		print &text('build_em4', "<tt>m4</tt>"),"<p>\n";
		&ui_print_footer("list_features.cgi", $text{'features_return'});
		exit;
		}

	$temp = &transname();
	$out = `$cmd 2>&1 >$temp`;
	if ($?) {
		print &text('build_ebuild', "<pre>$out</pre>"),"<p>\n";
		&ui_print_footer("list_features.cgi", $text{'features_return'});
		exit;
		}
	if (&has_command("diff") && -r $config{'sendmail_cf'}) {
		$diff = `diff $config{'sendmail_cf'} $temp 2>/dev/null`;
		if (!$diff) {
			print "$text{'build_nodiff'}<p>\n";
			&ui_print_footer("list_features.cgi", $text{'features_return'});
			exit;
			}
		}
	
	print "<center><form action=build.cgi>\n";
	print "<input type=hidden name=confirm value=1>\n";
	print &text('build_rusure', "<tt>$config{'sendmail_cf'}</tt>",
		    "<tt>$config{'sendmail_mc'}</tt>"),"<p>\n";
	print $text{'build_rusure2'},"<p>\n";
	print "<input type=submit value='$text{'build_ok'}'>\n";
	print "</form></center>\n";

	if ($diff) {
		print "<b>$text{'build_diff'}</b><p>\n";
		print "<table border><tr $cb><td><pre>",
		      $diff,"</pre></td></tr></table><p>\n";
		}
	unlink($temp);

	&ui_print_footer("list_features.cgi", $text{'features_return'});
	}

