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
		&ui_print_header(undef, $text{'delete_title'}, "", "delete");
		print &text('delete_err', "<tt>$p</tt> :<br>$error"),"\n";
		&ui_print_footer(
		    "edit_pack.cgi?search=$in{'search'}&package=".&urlize($p).
		    "&version=".&urlize($v), $text{'edit_return'});
		return;
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
	&ui_print_header(undef, $text{'delete_title'}, "", "delete");

	# Sum up files
	$n = &check_files($p, $v);
	$sz = 0;
	for($i=0; $i<$n; $i++) {
		if ($files{$i,'type'} == 0) { $sz += $files{$i,'size'}; }
		}
	print "<center>\n";
	if ($n) {
		print &text('delete_rusure', "<tt>$p</tt>", $n, &nice_size($sz)),"<p>\n";
		}
	else {
		print &text('delete_rusure2', "<tt>$p</tt>"),"<p>\n";
		}

	# Ask if the user is sure..
	print &ui_form_start("delete_pack.cgi");
	print &ui_hidden("package", $p);
	print &ui_hidden("version", $v);
	print &ui_hidden("sure", 1);
	print &ui_hidden("search", $in{'search'});
	print &ui_submit($text{'delete_ok'}),"<p>\n";
	if (defined(&delete_options)) {
		&delete_options($p);
		}
	print &ui_form_end(),"</center>\n";

	&ui_print_footer(
		"edit_pack.cgi?search=$in{'search'}&package=".&urlize($p).
	 	"&version=".&urlize($v), $text{'edit_return'});
	}

