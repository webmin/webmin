#!/usr/local/bin/perl
# edit_delay.cgi
# Displays a list of existing delay pools

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'delay'} || &error($text{'delay_ecannot'});
&ui_print_header(undef, $text{'delay_title'}, "", "edit_delay", 0, 0, 0, &restart_button());
my $conf = &get_config();

# Display all known delay pools
my $pools = &find_value("delay_pools", $conf);
my @links = ( &select_all_link("d"),
	      &select_invert_link("d"),
	      &ui_link("edit_pool.cgi?new=1", $text{'delay_add'}) );
if ($pools) {
	my @pools = sort { $a->{'values'}->[0] <=> $b->{'values'}->[0] }
		      &find_config("delay_class", $conf);
	my @params = &find_config("delay_parameters", $conf);
	print &ui_form_start("delete_pools.cgi", "post");
	print &ui_links_row(\@links);
	my @tds = ( "width=5" );
	print &ui_columns_start([ "",
				  $text{'delay_num'},
				  $text{'delay_class'},
				  $text{'delay_agg'},
				  $text{'delay_ind'},
				  $text{'delay_net'},
				  $squid_version >= 3 ? (
					$text{'delay_user'},
					$text{'delay_tag'} ) : ( ),
				], 100, 0, \@tds);
	foreach my $p (@pools) {
		my ($pr) = grep { $_->{'values'}->[0] ==
				  $p->{'values'}->[0] } @params;
		my @cols;
		push(@cols, &ui_link("edit_pool.cgi?idx=$p->{'values'}->[0]",
				     $p->{'values'}->[0]));
		push(@cols, $text{"delay_class_$p->{'values'}->[1]"});
		if ($p->{'values'}->[1] == 5) {
			push(@cols, "", "", "", "");
			push(@cols, &pool_param($pr->{'values'}->[1]));
			}
		else {
			push(@cols, &pool_param($pr->{'values'}->[1]));
			if ($p->{'values'}->[1] == 2) {
				push(@cols, &pool_param($pr->{'values'}->[2]));
				push(@cols, "");
				}
			else {
				push(@cols, &pool_param($pr->{'values'}->[3]));
				push(@cols, &pool_param($pr->{'values'}->[2]));
				}
			if ($squid_version >= 3) {
				if ($p->{'values'}->[1] == 4) {
					push(@cols, &pool_param(
						$pr->{'values'}->[4]));
					}
				else {
					push(@cols, "");
					}
				push(@cols, "");
				}
			}
		print &ui_checked_columns_row(\@cols, \@tds,
					      "d", $p->{'values'}->[0]);
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'delay_delete'} ] ]);
	}
else {
	print "<b>$text{'delay_none'}</b><p>\n";
	print &ui_links_row([ $links[2] ]);
	}

print &ui_form_start("save_delay.cgi", "post");
print &ui_table_start($text{'delay_header'}, undef, 4);

print &opt_input($text{'delay_initial'}, "delay_initial_bucket_level", $conf,
		 $text{'default'}, 4, "%");

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'eicp_return'});

# pool_param(param)
sub pool_param
{
my ($param) = @_;
if ($param =~ /^([0-9\-]+)\/([0-9\-]+)$/) {
	return $1 == -1 ? $text{'delay_unlimited'} :
		&text('delay_param', "$1", "$2");
	}
else {
	return $param;	# huh?
	}
}

