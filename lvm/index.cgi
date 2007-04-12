#!/usr/local/bin/perl
# index.cgi
# Display a table of all volumne groups and their physical and logical volumes.

require './lvm-lib.pl';

if (!&has_command("vgdisplay")) {
	&lvm_header();
	print "<p>",&text('index_ecommands', "<tt>vgdisplay</tt>"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}
($lvm_version, $out) = &get_lvm_version();
if ($lvm_version && $lvm_version < 2) {
	# /proc/lvm doesn't exist in LVM 2
	if (!-d $lvm_proc) {
		system("modprobe lvm-mod >/dev/null 2>&1");
		}
	if (!-d $lvm_proc) {
		&lvm_header();
		print "<p>",&text('index_emodule', "<tt>$lvm_proc</tt>",
				  "<tt>lvm-mod</tt>"),"<p>\n";
		&ui_print_footer("/", $text{'index'});
		exit;
		}
	}
if (!$lvm_version) {
	&lvm_header();
	print "<p>",&text('index_eversion', "<tt>vgdisplay --version</tt>",
			  "<pre>$out</pre>"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}
&lvm_header();

# Show table of volume groups
@vgs = &list_volume_groups();
if (@vgs) {
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'index_vgs'}</b></td> ",
	      "<td><b>$text{'index_pvs'}</b></td> ",
	      "<td><b>$text{'index_lvs'}</b></td> </tr>\n";
	foreach $v (sort { $a->{'number'} <=> $b->{'number'} } @vgs) {
		# Show volume group icon
		print "<tr $cb> <td valign=top width=20%>\n";
		&icons_table( [ "edit_vg.cgi?vg=".&urlize($v->{'name'}) ],
			      [ &html_escape($v->{'name'}).
				"<br>".&nice_size($v->{'size'}*1024) ],
			      [ "images/vg.gif" ], 1);
		print &ui_links_row([
			"<a href='edit_vg.cgi'>$text{'index_add'}</a>" ]);
		print "</td> <td valign=top width=40%>\n";

		# Show physical volume icons
		local @pvs = sort { $a->{'number'} <=> $b->{'number'} }
				  &list_physical_volumes($v->{'name'});
		if (@pvs) {
			local (@icons, @titles, @links);
			@icons = map { "images/pv.gif" } @pvs;
			@titles = map { &html_escape($_->{'device'}).
					"<br>".&nice_size($_->{'size'}*1024) } @pvs;
			@links = map { "edit_pv.cgi?vg=".&urlize($v->{'name'}).
				       "&pv=".&urlize($_->{'name'}) } @pvs;
			&icons_table(\@links, \@titles, \@icons, 3);
			}
		else {
			print "<b>$text{'index_nopvs'}</b><p>\n";
			}
		print &ui_links_row([
			"<a href='edit_pv.cgi?vg=".&urlize($v->{'name'}).
			  "'>$text{'index_addpv'}</a>" ]);

		# Show logical volume icons
		print "</td> <td valign=top width=40%>\n";
		local @lvs = sort { $a->{'number'} <=> $b->{'number'} }
				  &list_logical_volumes($v->{'name'});
		if (@lvs) {
			@icons = map { $_->{'is_snap'} ? "images/snap.gif"
						       : "images/lv.gif" } @lvs;
			@titles = map { &html_escape($_->{'name'}).
					"<br>".&nice_size($_->{'size'}*1024) } @lvs;
			@links = map { "edit_lv.cgi?vg=".&urlize($v->{'name'}).
				       "&lv=".&urlize($_->{'name'}) } @lvs;
			&icons_table(\@links, \@titles, \@icons, 3);
			}
		else {
			print "<b>$text{'index_nolvs'}</b><p>\n";
			}
		print &ui_links_row([
			"<a href='edit_lv.cgi?vg=".&urlize($v->{'name'}).
			  "'>$text{'index_addlv'}</a>",
			@lvs ? (
			  "<a href='edit_lv.cgi?vg=".&urlize($v->{'name'}).
		            "&snap=1'>$text{'index_addsnap'}</a>" ) : ( )
			]);
		print "</td> </tr>\n";
		}
	print "</table><p>\n";
	}
else {
	print "<b>$text{'index_none'}</b> <p>\n";
	@tab = &list_lvmtab();
	if (@tab) {
		# Maybe LVM needs to be re-started
		print &text('index_init', "init.cgi"),"<p>\n";
		}
	print &ui_links_row([
		"<a href='edit_vg.cgi'>$text{'index_add'}</a>" ]);
	}

&ui_print_footer("/", $text{'index'});

sub lvm_header
{
&ui_print_header(undef, $text{'index_title'}, "", undef, 0, 1, 0,
	&help_search_link("lvm", "man", "doc", "google"), undef, undef,
	$lvm_version ? &text('index_version', $lvm_version) : undef);
}

