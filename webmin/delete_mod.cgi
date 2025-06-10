#!/usr/local/bin/perl
# delete_mod.cgi
# Delete selected modules from webmin, after asking first

require './webmin-lib.pl';
&ReadParse();
&error_setup($text{'delete_err'});
@mods = split(/\0/, $in{'mod'});
@mods || &error($text{'delete_enone'});

# check if any other module depends on those to be deleted
foreach $minfo (&get_all_module_infos()) {
	if (&check_os_support($minfo) && &indexof($minfo->{'dir'}, @mods) < 0) {
		foreach $d (split(/\s+/, $minfo->{'depends'})) {
			if (&indexof($minfo->{'dir'}, @mods) < 0) {
				$depends{$d} = $minfo->{'desc'};
				}
			}
		}
	}
foreach $m (@mods) {
	%minfo = &get_module_info($m);
	%minfo = &get_theme_info($m) if (!%minfo);
	if (!$in{'nodeps'} && !-l &module_root_directory($m) && $depends{$m}) {
		&error(&text('delete_edep', "<tt>$minfo{'desc'}</tt>",
			     "<tt>$depends{$m}</tt>"));
		}
	}

# ask the user if he is sure
if (!$in{'confirm'}) {
	&ui_print_header(undef, $text{'delete_title'}, "");
	print &ui_form_start("delete_mod.cgi", "post");
	foreach $m (@mods) {
		my %minfo = &get_module_info($m);
		if (%minfo) {
			$module++;
			}
		else {
			$theme++;
			%minfo = &get_theme_info($m);
			}
		print &ui_hidden("mod", $m);
		$total += &disk_usage_kb(&module_root_directory($m))
			if (!-l &module_root_directory($m));
		$descs .= " , " if ($descs);
		$descs .= "<b>$minfo{'desc'}</b>";
		}
	print "<center>",&text($theme ? 'delete_rusure2' :
			       $total ? 'delete_rusure' : 'delete_rusure3',
			       int($total), $descs),"<p>",
	      &ui_submit($text{'delete'}, "confirm"),"<br>\n";
	if ($module) {
		print &ui_checkbox("acls", 1, $text{'delete_acls'}, 0);
		}
	print &ui_hidden("nodeps", $in{'nodeps'}),"\n";
	print "</center>\n";
	print &ui_form_end();
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

# delete the selected modules or themes
foreach $m (split(/\0/, $in{'mod'})) {
	next if (!$m || !-d &module_root_directory($m));
	push(@mdesc, &delete_webmin_module($m, $in{'acls'}));
	}
&flush_webmin_caches();

&ui_print_header(undef, $text{'delete_title'}, "");
print $text{'delete_msg'},"<p>\n";
print "<ul>\n";
for($i=0; $i<@mdesc; $i++) {
	print $mdesc[$i],"<p>\n";
	}
print "</ul><p>\n";

if (defined(&theme_post_change_modules)) {
	&theme_post_change_modules();
	}

&ui_print_footer("", $text{'index_return'});

