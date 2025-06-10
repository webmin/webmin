#!/usr/local/bin/perl
# Show services in nsswitch.conf, with links to edit them

if (-r 'ldap-client-lib.pl') {
	require './ldap-client-lib.pl';
	}
else {
	require './nis-lib.pl';
	}
require './switch-lib.pl';
&ui_print_header(undef, $text{'switch_title'}, "",
		 $module_name eq "nis" ? undef : "switch");

print &ui_columns_start([ $text{'switch_service'},
			  $text{'switch_srcs'} ], undef, 0,
			[ "nowrap", "nowrap" ]);
$conf = &get_nsswitch_config();
foreach $s (@$conf) {
	$srcs = join(", ", map { $text{'order_'.$_->{'src'}} } @{$s->{'srcs'}});
	$name = $text{'desc_'.$s->{'name'}} || $s->{'name'};
	print &ui_columns_row([
		&ui_link("edit_switch.cgi?name=$s->{'name'}",$name),
		$srcs,
		]);
	}
print &ui_columns_end();

&ui_print_footer("", $text{'index_return'});

