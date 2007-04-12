#!/usr/local/bin/perl
# delete_pack.cgi
# Ask if the user wants to delete a package, and if so do it

require './software-lib.pl';
&ReadParse();
$p = $in{'package'};
$v = $in{'version'};
&error_setup(&text('delete_err', $p));
(@pinfo = &package_info($p, $v)) ||
	&error(&text('delete_epack', $p));

if ($in{'sure'}) {
	# do the deletion
	&list_packages($p);
	if ($error = &delete_package($p, \%in, $v)) {
		&error($error);
		}
	&webmin_log("delete", "package", $p, { 'desc' => $packages{0,'desc'} });
	if ($in{'search'}) {
		&redirect("search.cgi?search=$in{'search'}");
		}
	else {
		&redirect("");
		}
	}
else {
	# Ask if the user is sure..
	&ui_print_header(undef, $text{'delete_title'}, "", "delete");

	$n = &check_files($p, $v);
	$sz = 0;
	for($i=0; $i<$n; $i++) {
		if ($files{$i,'type'} == 0) { $sz += $files{$i,'size'}; }
		}
	print "<center>\n";
	print &text('delete_rusure', "<tt>$p</tt>", $n, $sz),"<br>\n";
	print "<form action=delete_pack.cgi>\n";
	print "<input type=hidden name=package value=\"$p\">\n";
	print "<input type=hidden name=version value=\"$v\">\n";
	print "<input type=hidden name=sure value=1>\n";
	print "<input type=hidden name=search value=\"$in{'search'}\">\n";
	print "<input type=submit value=\"$text{'delete_ok'}\"><p>\n";
	if (defined(&delete_options)) {
		&delete_options($p);
		}
	print "</center></form>\n";

	&ui_print_footer("edit_pack.cgi?search=$in{'search'}&package=".&urlize($p).
	 	"&version=".&urlize($v), $text{'edit_return'});
	}

