#!/usr/local/bin/perl
# delete_packs.cgi
# Ask if the user wants to delete multiple packages, and if so do it
# XXX logging

require './software-lib.pl';
&ReadParse();
&error_setup($text{'deletes_err'});
foreach $d (split(/\0/, $in{'del'})) {
	local ($p, $v) = split(/\s/, $d);
	local @pinfo;
	(@pinfo = &package_info($p, $v)) ||
		&error(&text('delete_epack', $p));
	push(@packs, $p);
	push(@vers, $v);
	push(@infos, \@pinfo);
	}
@packs || &error($text{'deletes_enone'});

&ui_print_header(undef, $text{'deletes_title'}, "", "delete");

if ($in{'sure'}) {
	# do the deletion
	print "\n";
	if (defined(&delete_packages)) {
		# Can just use one function
		print &text('deletes_desc', "<tt>".join(" ", @packs)."</tt>"),
		      "\n";
		$error = &delete_packages(\@packs, \%in, \@vers);
		if ($error) {
			print &text('deletes_failed2', $error),"\n";
			}
		else {
			print "$text{'deletes_success2'}\n";
			}
		}
	else {
		# Need to use a loop
		for($i=0; $i<@packs; $i++) {
			$error = &delete_package($packs[$i], \%in, $vers[$i]);
			if ($error) {
				print &text('deletes_failed1', "<tt>$packs[$i]</tt>", $error),"<br>\n";
				}
			else {
				print &text('deletes_success1', "<tt>$packs[$i]</tt>"),"<br>\n";
				}
			}
		}
	&webmin_log("deletes", "package", undef, { 'packs' => \@packs });
	}
else {
	# Ask if the user is sure..
	print "<center>\n";
	print &text('deletes_rusure', "<tt>".join(" ", @packs)."</tt>"),
	      "<p>\n";
	print &ui_form_start("delete_packs.cgi", "post");
	foreach $d (split(/\0/, $in{'del'})) {
		print &ui_hidden("del", $d);
		}
	print &ui_hidden("sure", 1);
	print &ui_hidden("search", $in{'search'});
	print &ui_submit($text{'deletes_ok'}),"<p>\n";
	if (defined(&delete_options)) {
		&delete_options($packs[0]);
		}
	print &ui_form_end(),"</center>\n";

	}

&ui_print_footer("search.cgi?search=$in{'search'}", $text{'search_return'});

