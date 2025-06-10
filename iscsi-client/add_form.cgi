#!/usr/local/bin/perl
# Show a form for adding a connection

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './iscsi-client-lib.pl';
our (%text, %in);
&ReadParse();
&error_setup($text{'add_err'});

# Validate inputs
&to_ipaddress($in{'host'}) || &to_ip6address($in{'host'}) ||
	&error($text{'add_ehost'});
$in{'port_def'} || $in{'port'} =~ /^\d+$/ ||
	&error($text{'add_eport'});

&ui_print_header(undef, $text{'add_title'}, "");

# Get list of targets from the host
my $targets = &list_iscsi_targets(
	$in{'host'}, $in{'port_def'} ? undef : $in{'port'}, $in{'iface'});
ref($targets) || &error(&text('add_etargets', $in{'host'}, $targets));
@$targets || &error(&text('add_etargets2', $in{'host'}));

# Make map of current connections
my $conns = &list_iscsi_connections();
my %used = map { $_->{'name'}.":".$_->{'target'}, $_ }
	       grep { $_->{'ip'} eq &to_ipaddress($in{'host'}) ||
		      $_->{'ip'} eq &to_ip6address($in{'host'}) } @$conns;

# Show form to select target
print &ui_form_start("add_conn.cgi", "post");
print &ui_hidden("host", $in{'host'});
print &ui_hidden("port", $in{'port_def'} ? undef : $in{'port'});
print &ui_hidden("iface", $in{'iface'});
print &ui_table_start($text{'conns_header'}, undef, 2);

print &ui_table_row($text{'conns_host'}, $in{'host'});
print &ui_table_row($text{'conns_port'},
	$in{'port_def'} ? $text{'default'} : $in{'port'});
print &ui_table_row($text{'conns_iface'},
	$in{'iface'} || "<i>$text{'conns_ifacedef'}</i>");

# Target to mount
print &ui_table_row($text{'add_target'},
	&ui_select("target", undef,
		[ [ "", "&lt;".$text{'add_alltargets'}."&gt;" ],
		  map { my $u = $used{$_->{'name'}.":".$_->{'target'}};
			[ $_->{'name'}.":".$_->{'target'},
			  &text('add_on', $_->{'target'}, $_->{'ip'}).
			  (!$u ? "" :
			   $u->{'device'} ? " (".&text('add_dev',
						       $u->{'device'}).")"
					  : " (".$text{'add_used'}.")"),
			] } @$targets ]));

# Username, password and authentication method
print &ui_table_row($text{'add_auth'},
	&ui_radio("auth_def", 1,
		[ [ 1, $text{'add_auth1'}."<br>" ],
		  [ 0, &text('add_auth0',
			&ui_select("authmethod", "CHAP",
			   [ [ "None", $text{'auth_method_none'} ],
			     [ "CHAP" ] ]),
			&ui_textbox("authuser", undef, 15),
			&ui_textbox("authpass", undef, 15)) ] ]));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'add_ok'} ] ]);

&ui_print_footer("list_conns.cgi", $text{'conns_return'});
