#!/usr/local/bin/perl
# edit_vg.cgi
# Display a form for editing or creating a volume group

require './lvm-lib.pl';
&ReadParse();

if ($in{'vg'}) {
	($vg) = grep { $_->{'name'} eq $in{'vg'} } &list_volume_groups();
	$vg || &error($text{'vg_egone'});
	&ui_print_header(undef, $text{'vg_edit'}, "");
	}
else {
	&ui_print_header(undef, $text{'vg_create'}, "");
	}

print &ui_form_start("save_vg.cgi");
print &ui_hidden("vg", $in{'vg'});
print &ui_table_start($text{'vg_header'}, "width=100%", 4);

# VG name
print &ui_table_row($text{'vg_name'},
	&ui_textbox("name", $vg->{'name'}, 20));

if ($in{'vg'}) {
	# Details of existing VG
	print &ui_table_row($text{'vg_size'},
		&nice_size($vg->{'size'}*1024));

	print &ui_table_row($text{'vg_petotal'},
		&text('lv_petotals', $vg->{'pe_alloc'}, $vg->{'pe_total'}));

	print &ui_table_row($text{'vg_pesize'},
		&nice_size($vg->{'pe_size'}*1024));

	print &ui_table_row($text{'vg_petotal2'},
		&text('lv_petotals',
			&nice_size($vg->{'pe_alloc'}*$vg->{'pe_size'}*1024),
			&nice_size($vg->{'pe_total'}*$vg->{'pe_size'}*1024)));
	}
else {
	# Extent size for new VG
	print &ui_table_row($text{'vg_pesize'},
		&ui_opt_textbox("pesize", undef, 8, $text{'default'})." kB");

	print &ui_table_row($text{'vg_device'},
		&device_input(), 3);
	}

print &ui_table_end();
if ($in{'vg'}) {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}

&ui_print_footer("index.cgi?mode=vgs", $text{'index_return'});

