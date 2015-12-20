#!/usr/local/bin/perl
# edit_os.cgi
# Show the current OS according to Webmin, and some environment settings

require './webmin-lib.pl';
&ui_print_header(undef, $text{'os_title'}, "");
&get_miniserv_config(\%miniserv);

print $text{'os_desc3'},"<br>\n";
print $text{'os_desc2'},"<p>\n";

print &ui_form_start("change_os.cgi", "post");
print &ui_table_start($text{'os_header'}, undef, 2, [ "width=40%" ]);

# OS according to Webmin
print &ui_table_row($text{'os_webmin'},
   &ui_select("type", $gconfig{'real_os_type'},
	[ map { [ $_ ] } sort { $a cmp $b } &unique(map { $_->{'realtype'} }
				 &list_operating_systems()) ])." ".
   &ui_textbox("version", $gconfig{'real_os_version'}, 10), undef, [ "valign=middle","valign=middle" ]);

# Internal OS code
print &ui_table_row($text{'os_iwebmin'},
    &ui_select("itype", $gconfig{'os_type'},
	[ map { [ $_ ] } sort { $a cmp $b } &unique(map { $_->{'type'} }
				 &list_operating_systems()) ])." ".
    &ui_textbox("iversion", $gconfig{'os_version'}, 10), undef, [ "valign=middle","valign=middle" ]);

# Detected OS
%osinfo = &detect_operating_system();
if ($osinfo{'real_os_type'}) {
	print &ui_table_row($text{'os_detect'},
		"$osinfo{'real_os_type'} $osinfo{'real_os_version'}\n".
		($osinfo{'os_type'} ne $gconfig{'os_type'} ||
		 $osinfo{'os_version'} ne $gconfig{'os_version'} ?
			"<br>".&ui_checkbox("update", 1, $text{'os_update'}) :
			""), undef, [ "valign=middle","valign=middle" ]);
	}
else {
	print &ui_table_row($text{'os_detect'},
			    "<i>$text{'os_cannot'}</i>");
	}

print &ui_table_hr();

# Search path
print &ui_table_row($text{'os_path'},
	&ui_textarea("path",
		     join("\n", split($path_separator, $gconfig{'path'})),
		     5, 30)."<br>".
	&ui_checkbox("syspath", 1, $text{'os_syspath'}, !$gconfig{'syspath'}));

# Shared library path
if ($gconfig{'ld_env'}) {
	print &ui_table_row($text{'os_ld_path'},
		&ui_textarea("ld_path",
		     join("\n", split($path_separator, $gconfig{'ld_path'})),
		     5, 30));
	}

# Perl search path
print &ui_table_row($text{'os_perllib'},
	&ui_textarea("perllib",
	     join("\n", split(":", $miniserv{'perllib'})), 3, 30));

# Global environment variables
$atable = &ui_columns_start([ $text{'os_name'}, $text{'os_value'} ]);
$i = 0;
foreach $e (keys %miniserv) {
	if ($e =~ /^env_(\S+)$/ &&
	    $1 ne "WEBMIN_CONFIG" && $1 ne "WEBMIN_VAR") {
		$atable .= &ui_columns_row([
			&ui_textbox("name_$i", $1, 20),
			&ui_textbox("value_$i", $miniserv{$e}, 30)
			]);
		$i++;
		}
	}
$atable .= &ui_columns_row([ &ui_textbox("name_$i", undef, 20),
			     &ui_textbox("value_$i", undef, 30) ]);
$atable .= &ui_columns_end();
print &ui_table_row($text{'os_envs'}, $atable);

print &ui_table_end();
print &ui_form_end([ [ "", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

