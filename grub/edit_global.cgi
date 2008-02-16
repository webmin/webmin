#!/usr/local/bin/perl
# edit_global.cgi
# Edit global GRUB options

require './grub-lib.pl';
&foreign_require("fdisk", "fdisk-lib.pl");
$conf = &get_menu_config();
&ui_print_header(undef, $text{'global_title'}, "");

print &ui_form_start("save_global.cgi");
print &ui_table_start($text{'global_header'}, "width=100%", 4);

# Default kernel to boot
$default = &find_value("default", $conf);
@titles = &find_value("title", $conf);
print &ui_table_row($text{'global_default'},
	&ui_select("default", $default,
		   [ [ '', $text{'global_first'} ],
		     map { [ $_, $titles[$_] ] } (0..$#titles) ]));

# Fallback kernel
$fallback = &find_value("fallback", $conf);
print &ui_table_row($text{'global_fallback'},
	&ui_select("fallback", $fallback,
		   [ [ '', $text{'global_first'} ],
		     map { [ $_, $titles[$_] ] } (0..$#titles) ]));

# Boot timeout
$timeout = &find_value("timeout", $conf);
print &ui_table_row($text{'global_timeout'},
	&ui_opt_textbox("timeout", $timeout,  5, $text{'global_forever'}).
	" ".$text{'global_secs'}, 3);

# Boot-time password
$password = &find("password", $conf);
@pv = split(/\s+/, $password->{'value'}) if ($password);
print &ui_table_row($text{'global_password'},
	&ui_opt_textbox("password", $password, 30, $text{'global_none'})."<br>".
	&ui_checkbox("password_file", 1, $text{'global_password_file'}, $pv[1]).
	" ".&ui_textbox("password_filename", $pv[1], 30), 3);

# Partition to install on
$r = $config{'install'};
$dev = &bios_to_linux($r);
$sel = &foreign_call("fdisk", "partition_select", "install", $dev, 2, \$found);
print &ui_table_row($text{'global_install'},
	&ui_radio("install_mode", $found ? 1 : 0,
		  [ [ 1, $text{'global_sel'}." ".$sel."<br>" ],
		    [ 0, $text{'global_other'}." ".
			 &ui_textbox("other", $found ? "" : $r, 30) ] ]), 3);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

