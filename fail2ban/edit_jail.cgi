#!/usr/local/bin/perl
# Show a form for editing or creating an jail

use strict;
use warnings;
require './fail2ban-lib.pl';
our (%in, %text);
&ReadParse();

# Get default jail
my @jails = &list_jails();
my ($def) = grep { $_->{'name'} eq 'DEFAULT' } @jails;

# Show header and get the jail object
my ($jail);
if ($in{'new'}) {
	&ui_print_header(undef, $text{'jail_title1'}, "");
	$jail = { };
	}
else {
	&ui_print_header(undef, $text{'jail_title2'}, "");
	($jail) = grep { $_->{'name'} eq $in{'name'} } @jails;
	$jail || &error($text{'jail_egone'});
	}

print &ui_form_start("save_jail.cgi", "post");
print &ui_hidden("new", $in{'new'});
print &ui_hidden("old", $in{'name'});
print &ui_table_start($text{'jail_header'}, undef, 2);

# Jail name
print &ui_table_row($text{'jail_name'},
	&ui_textbox("name", $jail->{'name'}, 30));

# Enabled or disabled?
my $enabled = &find_value("enabled", $jail);
print &ui_table_row($text{'jail_enabled'},
	&ui_yesno_radio("enabled", $enabled =~ /true|yes|1/i));

# Filter to match
my @filters = &list_filters();
my $filter = &find_value("filter", $jail);
print &ui_table_row($text{'jail_filter'},
	&ui_select("filter",
		   $filter,
		   [ [ undef, "&lt;$text{'default'}&gt;" ],
		     map { &filename_to_name($_->[0]->{'file'}) } @filters ],
		   1, 0, $filter ? 1 : 0));

# Actions to run
my $actionlist = &find("action", $jail);
my @actions = &list_actions();
my $atable = &ui_columns_start([
		$text{'jail_action'},
		$text{'jail_aname'},
		$text{'jail_port'},
		$text{'jail_protocol'},
		$text{'jail_others'},
		]);
my $i = 0;
foreach my $a (@{$actionlist->{'words'}}, undef) {
	my $action;
	my %opts;
	if ($a && $a =~ /^(\S+)\[(.*)\]$/) {
		$action = $1;
		%opts = map { my ($n, $v) = split(/=/, $_);
			      $v =~ s/^"(.*)"/$1/;
			      ($n, $v) } split(/,\s+/, $2);
		}
	else {
		$action = $a;
		}
	my @oopts = grep { !/^(name|port|protocol)$/ } (keys %opts);
	$atable .= &ui_columns_row([
		&ui_select("action_$i", $action,
		   [ [ "", "&nbsp;" ],
		     map { &filename_to_name($_->[0]->{'file'}) } @actions ],
		   1, 0, $action ? 1 : 0),
		&ui_textbox("name_$i", $opts{'name'}, 15),
		&ui_textbox("port_$i", $opts{'port'}, 6),
		&ui_select("protocol_$i", $opts{'protocol'},
			   [ [ '', '&nbsp;' ],
			     [ 'tcp', 'TCP' ],
			     [ 'udp', 'UDP' ],
			     [ 'icmp', 'ICMP' ] ]),
		&ui_textbox("others_$i",
			join(" ", map { $_."=".$opts{$_} } @oopts), 40),
		]);
	$i++;
	}
$atable .= &ui_columns_end();
print &ui_table_row($text{'jail_actions'}, $atable);

# Log file paths
my $logpath = &find_value("logpath", $jail);
print &ui_table_row($text{'jail_logpath'},
	&ui_textarea("logpath", $logpath, 5, 80, "hard"));

# Matches needed
my $def_maxretry = &find_value("maxretry", $def) || 3;
my $maxretry = &find_value("maxretry", $jail);
print &ui_table_row($text{'jail_maxretry'},
	&ui_opt_textbox("maxretry", $maxretry, 6,
			$text{'default'}." (".$def_maxretry.")"));

# Time to scan over
my $def_findtime = &find_value("findtime", $def) || 600;
my $findtime = &find_value("findtime", $jail);
print &ui_table_row($text{'jail_findtime'},
	&ui_opt_textbox("findtime", $findtime, 6,
			$text{'default'}." (".$def_findtime.")"));

# Time to ban for
my $def_bantime = &find_value("bantime", $def) || 600;
my $bantime = &find_value("bantime", $jail);
print &ui_table_row($text{'jail_bantime'},
	&ui_opt_textbox("bantime", $bantime, 6,
			$text{'default'}." (".$def_bantime.")"));

# IPs to ignore
my $def_ignoreip = &find_value("ignoreip", $def) || "127.0.0.1";
my $ignoreip = &find_value("ignoreip", $jail);
print &ui_table_row($text{'jail_ignoreip'},
	&ui_opt_textbox("ignoreip", $ignoreip, 40,
			$text{'default'}." (".$def_ignoreip.")"));

print &ui_table_end();
if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer("list_jails.cgi", $text{'jails_return'});

