#!/usr/local/bin/perl
# edit_record.cgi
# Edit an existing record of some type
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%access, %text, %in); 

require './bind8-lib.pl';
&ReadParse();
my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
my $dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'recs_ecannot'});
my $type = $zone->{'type'};
my $file = $zone->{'file'};
my @recs = &read_zone_file($file, $dom);
my $rec = &find_record_by_id(\@recs, $in{'id'}, $in{'num'});
$rec || &error($text{'edit_egone'});
&can_edit_type($rec->{'type'}, \%access) ||
	&error($text{'recs_ecannottype'});

my $desc = &text('edit_header', &zone_subhead($zone));
&ui_print_header($desc, &text('edit_title', $text{"edit_".$rec->{'type'}} || $rec->{'type'}), "",
		 undef, undef, undef, undef, &restart_links($zone));

&record_input($in{'zone'}, $in{'view'}, $in{'type'}, $file,
	      $dom, $in{'num'}, $rec);
&ui_print_footer("", $text{'index_return'},
	"edit_$type.cgi?zone=$in{'zone'}&view=$in{'view'}",
	$text{'recs_return'},
	"edit_recs.cgi?zone=$in{'zone'}&view=$in{'view'}&type=$in{'type'}",
	$text{'edit_return'});

