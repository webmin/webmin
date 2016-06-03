#!/usr/local/bin/perl
# edit_text.cgi
# Display a form for manually editing a records file
use strict;
use warnings;
our (%access, %text, %in);

require './bind8-lib.pl';
&ReadParse();
my $zone = &get_zone_name_or_error($in{'zone'}, $in{'view'});
my $file = &absolute_path($zone->{'file'});
my $tv = $zone->{'type'};
&can_edit_zone($zone) ||
	&error($text{'master_ecannot'});
$access{'file'} || &error($text{'text_ecannot'});
&ui_print_header($file, $text{'text_title'}, "",
		 undef, undef, undef, undef, &restart_links($zone));

my $text = &read_file_contents(&make_chroot($file));
if (!$access{'ro'}) {
	print &text('text_desc3', "<tt>$file</tt>"),"<p>\n";
	}

print &ui_form_start("save_text.cgi", "form-data");
print &ui_table_start(undef, "width=100%", 2);
print &ui_hidden("zone", $in{'zone'});
print &ui_hidden("view", $in{'view'});
print &ui_table_row(undef, &ui_textarea("text", $text, 20, 80,
					undef, 0, "style='width:100%'"), 2);
print &ui_table_row(undef, &ui_checkbox("soa", 1, $text{'text_soa'}, 1), 2);
print &ui_table_end();
print &ui_form_end($access{'ro'} ? [ ] : [ [ undef, $text{'save'} ] ]);

&ui_print_footer(($tv eq "master" ? "edit_master.cgi" :
	 $tv eq "forward" ? "edit_forward.cgi" : "edit_slave.cgi").
	"?zone=$in{'zone'}&view=$in{'view'}", $text{'master_return'});
