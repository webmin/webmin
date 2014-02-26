#!/usr/local/bin/perl
# Show a list of per-function cache manager passwords

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'cachemgr'} || &error($text{'cachemgr_ecannot'});
&ui_print_header(undef, $text{'cachemgr_title'}, "", "edit_cachemgr", 0, 0, 0,
		 &restart_button());

# Find password directives
my $conf = &get_config();
my @cachemgr = &find_config("cachemgr_passwd", $conf);

# Show them in a table
print &ui_form_start("save_cachemgr.cgi", "post");
print &ui_radio("cachemgr_def", @cachemgr ? 0 : 1,
    [ [ 1, $text{'cachemgr_def1'} ], [ 0, $text{'cachemgr_def0'} ] ]),"<br>\n";
print &ui_columns_start([ $text{'cachemgr_pass'},
			  $text{'cachemsg_actions'} ], 100, 0);
my $i = 0;
foreach my $c (@cachemgr, { 'values' => [ 'none' ] }) {
	my @grid = ( );
	my ($p, @acts) = @{$c->{'values'}};
	my %acts = map { $_, 1 } @acts;
	foreach my $a (&list_cachemgr_actions()) {
		push(@grid, &ui_checkbox("action_$i", $a, $a, $acts{$a}));
		delete($acts{$a});
		}
	my @others = grep { $_ ne 'all' } keys %acts;
	my $pmode = $p eq "none" ? "none" : $p eq "disable" ? "disable" : undef;
	print &ui_columns_row([
		&ui_radio("pass_def_$i", $pmode,
			  [ [ "none", $text{'cachemgr_none'}."<br>" ],
			    [ "disable", $text{'cachemgr_disable'}."<br>" ],
			    [ "", $text{'cachemgr_set'} ] ])." ".
		&ui_textbox("pass_$i", $pmode ? "" : $p, 15),
		&ui_checkbox("all_$i", 1, $text{'cachemgr_all'}, $acts{'all'}).
		"<br>\n".
		&ui_grid_table(\@grid, 6, 100).
		(@others ? "<br>\n".$text{'cachemgr_others'}." ".
			   &ui_textbox("others_$i", join(" ", @others), 40)
			 : "")
		 ], [ "valign=top", "valign=top" ]);
	$i++;
	}
print &ui_columns_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
