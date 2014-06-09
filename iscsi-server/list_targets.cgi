#!/usr/local/bin/perl
# List all targets (networks exported to)

use strict;
use warnings;
require './iscsi-server-lib.pl';
our (%text);
my $conf = &get_iscsi_config();

&ui_print_header(undef, $text{'targets_title'}, "");

my @targets = &find($conf, "target");
my @links = ( &ui_link("edit_target.cgi?new=1",$text{'targets_add'}) );
if (@targets) {
	unshift(@links, &select_all_link("d"), &select_invert_link("d"));
	print &ui_form_start("delete_targets.cgi");
	print &ui_links_row(\@links);
	my @tds = ( "width=5" );
	print &ui_columns_start([ undef, 
				  $text{'targets_name'},
				  $text{'targets_flags'},
				  $text{'targets_export'},
				  $text{'targets_network'} ], 100, 0, \@tds);
	my %omap = map { $_->{'type'}.$_->{'num'}, $_ } @$conf;
	foreach my $e (@targets) {
		print &ui_checked_columns_row([
			&ui_link("edit_target.cgi?num=$e->{'num'}","$e->{'type'}.$e->{'num'}"),
			$text{'targets_flags_'.$e->{'flags'}} ||
			  uc($e->{'flags'}),
			&describe_object($omap{$e->{'export'}}),
			$e->{'network'} eq "any" ||
			  $e->{'network'} eq "all" ||
			  $e->{'network'} =~ /^0(\.0)*\/0$/ ?
			    $text{'target_network_all'} : $e->{'network'},
			], \@tds, "d", $e->{'num'});
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([ [ undef, $text{'targets_delete'} ] ]);
	}
else {
	print "<b>$text{'targets_none'}</b><p>\n";
	print &ui_links_row(\@links);
	}

&ui_print_footer("", $text{'index_return'});
