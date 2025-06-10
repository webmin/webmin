#!/usr/local/bin/perl
# index.cgi
# Display a list of directories and their client(s)

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
require './exports-lib.pl';
our (%text);
&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
	&help_search_link("nfs exports", "man", "howto"));

if (!&has_nfs_commands()) {
	print $text{'index_eprog'},"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Display table of exports and clients
my @exps = &list_exports();
my @clinks = ( &ui_link("edit_export.cgi?new=1&ver=3", $text{'index_add'}) );
if (&nfs_max_version() >= 4) {
	push(@clinks, &ui_link("edit_export.cgi?new=1&ver=4",
			       $text{'index_add4'}));
	}
if (@exps) {
	print &ui_form_start("delete_exports.cgi", "post");
	my @dirs = &unique(map { $_->{'dir'} } @exps);

	# Directory list heading
	my @links = ( &select_all_link("d"),
		      &select_invert_link("d"),
		      @clinks );
	print &ui_links_row(\@links);
	my @tds = ( "width=5" );
	print &ui_columns_start([ "",
				  $text{'index_dir'},
				  $text{'index_to'} ], 100, 0, \@tds);

	# Rows for directories and clients
	foreach my $d (@dirs) {
		my @cols;
		push(@cols, &html_escape($d));
		my @cl = grep { $_->{'dir'} eq $d } @exps;
	    	my $ccount = 0;
		my $dirs = "";
		foreach my $c (@cl) {
			$dirs .= "&nbsp;|&nbsp; " if ($ccount++);
			$dirs .= &ui_link("edit_export.cgi?idx=$c->{'index'}",
					   &describe_host($c->{'host'}));
			if (!$c->{'active'}) {
				$dirs .= "<font color=#ff0000>(".
					 $text{'index_inactive'}.")</font>\n"
				}
			}
		push(@cols, $dirs);
		print &ui_checked_columns_row(\@cols, \@tds, "d", $d);
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ "delete", $text{'index_delete'} ],
			     [ "disable", $text{'index_disable'} ],
			     [ "enable", $text{'index_enable'} ] ]);
	}
else {
	print "<b>$text{'index_none'}</b> <p>\n";
	print &ui_links_row(\@clinks);
	}

print &ui_hr();
print &ui_buttons_start();
print &ui_buttons_row("restart_mountd.cgi", $text{'index_apply'},
		      $text{'index_applymsg'});
print &ui_buttons_end();

&ui_print_footer("/", $text{'index'});

