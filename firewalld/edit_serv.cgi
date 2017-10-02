#!/usr/local/bin/perl
# Show a form to edit one service

use strict;
use warnings;
require './firewalld-lib.pl';
our (%in, %text);
&ReadParse();

# Get the zone and rule
my @zones = &list_firewalld_zones();
my ($zone) = grep { $_->{'name'} eq $in{'zone'} } @zones;
$zone || &error($text{'port_ezone'});
my $serv;
if (!$in{'new'}) {
	&ui_print_header(undef, $text{'serv_edit'}, "");
	$serv = $in{'id'};
	}
else {
	&ui_print_header(undef, $text{'serv_create'}, "");
	}

print &ui_form_start("save_serv.cgi", "post");
print &ui_hidden("zone", $in{'zone'});
print &ui_hidden("id", $in{'id'});
print &ui_hidden("new", $in{'new'});
print &ui_table_start($text{'serv_header'}, undef, 2);

# Zone name
print &ui_table_row($text{'port_zone'},
		    "<tt>".&html_escape($zone->{'name'})."</tt>");

# Service name
print &ui_table_row($text{'serv_name'},
	&ui_select("serv", $serv, [ &list_firewalld_services() ]));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("index.cgi?zone=".&urlize($zone->{'name'}),
	         $text{'index_return'});
