#!/usr/local/bin/perl
# lists_configs.cgi
# List all usermin modules that can be configured

require './usermin-lib.pl';
$access{'configs'} || &error($text{'acl_ecannot'});
&ReadParse();
&ui_print_header(undef, $text{'configs_title'}, "");

@mods = &list_modules();
&get_usermin_miniserv_config(\%miniserv);
print "$text{'configs_desc'}<p>\n";
@grid = ( );

foreach $m (@mods) {
	if ((-r "$miniserv{'root'}/$m->{'dir'}/config.info" ||
	    -r "$miniserv{'root'}/$m->{'dir'}/uconfig.info") &&
	    &can_use_module($m->{'dir'})) {
		push(@grid, &ui_link("edit_configs.cgi?mod=".&urlize($m->{'dir'}), &html_escape($m->{'desc'})));
		}
	}
print &ui_grid_table(\@grid, 4, 100,
	[ "width=25%", "width=25%", "width=25%", "width=25%" ],
	undef, $text{'configs_header'});

&ui_print_footer("", $text{'index_return'});
