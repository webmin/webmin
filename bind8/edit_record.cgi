#!/usr/local/bin/perl
# edit_record.cgi
# Edit an existing record of some type

require './bind8-lib.pl';
&ReadParse();
$zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
$dom = $zone->{'name'};
&can_edit_zone($zone) ||
	&error($text{'recs_ecannot'});
$type = $zone->{'type'};
$file = $zone->{'file'};
@recs = &read_zone_file($file, $dom);
$rec = &find_record_by_id(\@recs, $in{'id'}, $in{'num'});
$rec || &error($text{'edit_egone'});
&can_edit_type($rec->{'type'}, \%access) ||
	&error($text{'recs_ecannottype'});

$desc = &text('edit_header', &ip6int_to_net(&arpa_to_ip($dom)));
&ui_print_header($desc, &text('edit_title', $text{"edit_".$rec->{'type'}} || $rec->{'type'}), "",
		 undef, undef, undef, undef, &restart_links($zone));

&record_input($in{'zone'}, $in{'view'}, $in{'type'}, $file,
	      $dom, $in{'num'}, $rec);
&ui_print_footer("", $text{'index_return'},
	"edit_$type.cgi?zone=$in{'zone'}&view=$in{'view'}",
	$text{'recs_return'},
	"edit_recs.cgi?zone=$in{'zone'}&type=$in{'type'}",
	$text{'edit_return'});

