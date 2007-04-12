#!/usr/local/bin/perl
# Show global policy settings

require './rbac-lib.pl';
$access{'policy'} || &error($text{'policy_ecannot'});
&ui_print_header(undef, $text{'policy_title'}, "", "policy");
$conf = &get_policy_config();

print &ui_form_start("save_policy.cgi", "post");
print &ui_table_start($text{'policy_header'}, "width=100%", 2);

print &ui_table_row($text{'policy_auths'},
		    &auths_input("auths",
				 &find_policy_value("AUTHS_GRANTED", $conf)));

print &ui_table_row($text{'policy_profs'},
	&profiles_input("profs", &find_policy_value("PROFS_GRANTED", $conf),1));

$allow = &find_policy_value("CRYPT_ALGORITHMS_ALLOW", $conf);
print &ui_table_row($text{'policy_allow'},
	&ui_radio("allow_def", $allow ? 0 : 1,
		  [ [ 1, $text{'default'} ],
		    [ 0, $text{'policy_sel'} ] ])."<br>\n".
	&crypt_algorithms_input("allow", $allow, 1));

$default = &find_policy_value("CRYPT_DEFAULT", $conf);
print &ui_table_row($text{'policy_default'},
	&ui_radio("default_def", $default ? 0 : 1,
		  [ [ 1, $text{'default'} ],
		    [ 0, " " ] ])."\n".
	&crypt_algorithms_input("default", $default, 0));

$deprecate = &find_policy_value("CRYPT_ALGORITHMS_DEPRECATE", $conf);
print &ui_table_row($text{'policy_deprecate'},
	&ui_radio("deprecate_def", $deprecate ? 0 : 1,
		  [ [ 1, $text{'policy_none'} ],
		    [ 0, " " ] ])."\n".
	&crypt_algorithms_input("deprecate", $deprecate, 0));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

