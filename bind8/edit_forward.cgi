#!/usr/local/bin/perl
# edit_forward.cgi
# Display options for an existing forward zone
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %in, %text);

require './bind8-lib.pl';
&ReadParse();

$in{'view'} = 'any' if ($in{'view'} eq '');
my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
my $z = &zone_to_config($zone);
my $zconf = $z->{'members'};
my $dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'master_ecannot'});

$dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'fwd_ecannot'});
&ui_print_header(&zone_subhead($zone), $text{'fwd_title'}, "",
		 undef, undef, undef, undef, &restart_links());

# Start of the form
print &ui_form_start("save_forward.cgi");
print &ui_hidden("zone", $in{'zone'});
print &ui_hidden("view", $in{'view'});
print &ui_table_start($text{'fwd_opts'}, "width=100%", 4);

# Forwarding servers
print &forwarders_input($text{'fwd_masters'}, "forwarders", $zconf);

print &choice_input($text{'fwd_forward'}, "forward", $zconf,
		    $text{'yes'}, "first", $text{'no'}, "only",
		    $text{'default'}, undef);
print &choice_input($text{'fwd_check'}, "check-names", $zconf,
		    $text{'warn'}, "warn", $text{'fail'}, "fail",
		    $text{'ignore'}, "ignore", $text{'default'}, undef);

print &ui_table_end();

if ($access{'ro'}) {
	print &ui_form_end();
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ] ]);

	print &ui_hr();
	print &ui_buttons_start();

	# Move to another view
	my $bconf = &get_config();
	print &move_zone_button($bconf, $zone->{'viewindex'}, $in{'zone'});

	# Delete zone
	if ($access{'delete'}) {
		print &ui_buttons_row("delete_zone.cgi",
			$text{'master_del'}, $text{'fwd_delmsg'},
			&ui_hidden("zone", $in{'zone'}).
			&ui_hidden("view", $in{'view'}));
		}

	print &ui_buttons_end();
	}
&ui_print_footer("", $text{'index_return'});

