#!/usr/local/bin/perl
# Show a form to re-write a disks partition table

require './fdisk-lib.pl';
&ReadParse();
&can_edit_disk($in{'device'}) || &error($text{'disk_ecannot'});

# Get the disk
@disks = &list_disks_partitions();
($d) = grep { $_->{'device'} eq $in{'device'} } @disks;
$d || &error($text{'disk_egone'});
@parts = @{$d->{'parts'}};
if (!@parts && $d->{'cylinders'} * $d->{'cylsize'} > 2*1024*1024*1024*1024) {
	# Recommend GPT format for new large disks
	$d->{'table'} = 'gpt';
	}
elsif (!@parts) {
	$d->{'table'} = $config{'format'};
	}

&ui_print_header($d->{'desc'}, $text{'relabel_title'}, "");

print "<b>",&text('relabel_warn', $d->{'desc'}, $d->{'device'}),"</b><p>\n";

print &ui_form_start("relabel.cgi");
print &ui_hidden("device", $in{'device'});
print &ui_table_start(undef, undef, 2);

print &ui_table_row($text{'relabel_parts'},
	join(", ", map { &tag_name($_->{'type'})." ".
			 &nice_size(($_->{'end'} - $_->{'start'} + 1) *
				    $d->{'cylsize'}) } @parts) ||
	$text{'relabel_noparts'});

print &ui_table_row($text{'relabel_table'},
	&ui_select("table", $d->{'table'},
		   [ map { [ $_, $text{'table_'.$_} || uc($_) ] }
			 &list_table_types($d) ]));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'relabel_ok'} ] ]);

&ui_print_footer("edit_disk.cgi?device=$dinfo->{'device'}",
		 $text{'disk_return'});

