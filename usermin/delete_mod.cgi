#!/usr/local/bin/perl
# delete_mod.cgi
# Delete selected modules from usermin

require './usermin-lib.pl';
$access{'umods'} || &error($text{'acl_ecannot'});
&ReadParse();
&error_setup($text{'delete_err'});
@mods = split(/\0/, $in{'mod'});
@mods || &error($text{'delete_enone'});

local %miniserv;
&get_usermin_miniserv_config(\%miniserv);

# Check if any other module depends on those to be deleted
# %depends maps module dirs to the descriptions of those that depend on them
foreach $minfo (&list_modules()) {
	if (&check_usermin_os_support($minfo)) {
		foreach $d (split(/\s+/, $minfo->{'depends'})) {
			if (&indexof($minfo->{'dir'}, @mods) < 0) {
				$depends{$d} = $minfo->{'desc'};
				}
			}
		}
	}
foreach $m (@mods) {
	%minfo = &get_usermin_module_info($m);
	%minfo = &get_usermin_theme_info($m) if (!%minfo);
	if (!-l "$miniserv{'root'}/$m" && $depends{$m}) {
		&error(&text('delete_edep',
			     "<tt>".&html_escape($minfo{'desc'})."</tt>",
			     "<tt>".&html_escape($depends{$m})."</tt>"));
		}
	}

# ask the user if he is sure
if (!$in{'confirm'}) {
	&ui_print_header(undef, $text{'delete_title'}, "");
	print "<p><form action=delete_mod.cgi>\n";
	foreach $m (@mods) {
		local %minfo = &get_usermin_module_info($m);
		if (!%minfo) {
			$theme++;
			%minfo = &get_usermin_theme_info($m);
			}
		print "<input type=hidden name=mod value=$m>\n";
		$total += &disk_usage_kb("$miniserv{'root'}/$m")
			if (!-l "$miniserv{'root'}/$m");
		$descs .= " , " if ($descs);
		$descs .= "<b>".&html_escape($minfo{'desc'})."</b>";
		}
	print "<center>",&text($theme ? 'delete_rusure2' : 'delete_rusure',
			       int($total), $descs),"<p>",
	      "<input type=submit name=confirm value='$text{'delete'}'>",
	      "</form></center>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

# delete the selected modules or themes
foreach $m (split(/\0/, $in{'mod'})) {
	next if (!$m || !-d "$miniserv{'root'}/$m");
	local $mdesc = &delete_usermin_module($m);
	if ($mdesc) {
		push(@mdesc, $mdesc);
		}
	}
&flush_modules_cache();

&ui_print_header(undef, $text{'delete_title'}, "");
print $text{'delete_msg'},"<p>\n";
print "<ul>\n";
for($i=0; $i<@mdesc; $i++) {
	print $mdesc[$i],"<p>\n";
	}
print "</ul><p>\n";
&ui_print_footer("", $text{'index_return'});

