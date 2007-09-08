#!/usr/local/bin/perl
# edit_configs.cgi
# Display the configs for a usermin module

require './usermin-lib.pl';
require '../config-lib.pl';
$access{'configs'} || &error($text{'acl_ecannot'});
&ReadParse();
&can_use_module($in{'mod'}) || &error($text{'configs_ecannot'});
&ui_print_header(undef, $text{'configs_title2'}, "");
&get_usermin_miniserv_config(\%miniserv);

# Show start of tabs
$prog = "edit_configs.cgi?mod=$in{'mod'}&mode=";
if (-r "$miniserv{'root'}/$in{'mod'}/config.info") {
	push(@tabs, [ "global", $text{'configs_global'}, $prog."global" ]);
	}
if (-r "$miniserv{'root'}/$in{'mod'}/uconfig.info") {
	push(@tabs, [ "user", $text{'configs_user'}, $prog."user" ]);
	}
print &ui_tabs_start(\@tabs, "mode", $in{'mode'} || $tabs[0]->[0], 1);

&read_file("$config{'usermin_dir'}/$in{'mod'}/config", \%mconfig);
if (-r "$miniserv{'root'}/$in{'mod'}/config.info") {
	# Display config form for the module
	print &ui_tabs_start_tab("mode", "global");
	print $text{'configs_globaldesc'},"<p>\n";
	%minfo = &get_usermin_module_info($in{'mod'});
	print &ui_form_start("save_configs.cgi", "post");
	print &ui_hidden("mod", $in{'mod'}),"\n";
	print &ui_table_start(&text('config_header', $minfo{'desc'}),
			      "width=100%", 2);

	# Use config.info to create config inputs
	&generate_config(\%mconfig, "$miniserv{'root'}/$in{'mod'}/config.info");
	print &ui_table_end();
	print &ui_form_end([ [ "save", $text{'save'} ] ]);
	print &ui_tabs_end_tab();
	}

if (-r "$miniserv{'root'}/$in{'mod'}/uconfig.info") {
	# Display default user config form for the module
	print &ui_tabs_start_tab("mode", "user");
	print $text{'configs_userdesc'},"<p>\n";
	%minfo = &get_usermin_module_info($in{'mod'});
	print &ui_form_start("save_uconfigs.cgi", "post");
	print &ui_hidden("mod", $in{'mod'}),"\n";
	print &ui_table_start(&text('configs_uheader', $minfo{'desc'}),
			      "width=100%", 2);

	&read_file("$miniserv{'root'}/$in{'mod'}/defaultuconfig", \%uconfig);
	&read_file("$config{'usermin_dir'}/$in{'mod'}/uconfig", \%uconfig);

	# Can edit prefs?
	&read_file("$config{'usermin_dir'}/$in{'mod'}/canconfig", \%canconfig);
	$noprefs = $mconfig{'noprefs'} == 1 ? 1 :
		   %canconfig ? 2 : 0;

	print &ui_table_row($text{'configs_prefs'},
		&ui_radio("noprefs", $noprefs,
			[ [ 0, $text{'yes'} ], [ 1, $text{'no'} ],
			  [ 2, $text{'configs_sels'} ] ]));
	print &ui_table_hr();

	# Use uconfig.info to create config inputs
	&generate_config(\%uconfig,
			 "$miniserv{'root'}/$in{'mod'}/uconfig.info",
			 undef, $noprefs == 2 ? \%canconfig : undef, "_can");
	print &ui_table_end();
	print &ui_form_end([ [ "save", $text{'save'} ] ]);
	print &ui_tabs_end_tab();
	}

print &ui_tabs_end(1);

&ui_print_footer("list_configs.cgi", $text{'configs_return'});

