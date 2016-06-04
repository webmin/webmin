#!/usr/local/bin/perl
# view_text.cgi
# Display the records in a zone
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
&ui_print_header($file, $text{'text_title2'}, "",
		 undef, undef, undef, undef, &restart_links($zone));

if (&is_raw_format_records(&make_chroot($file))) {
	print "$text{'text_rawformat'}<p>\n";
	}
else {
	print &text('text_desc2', "<tt>$file</tt>"),"<p>\n";

	my $text = &read_file_contents(&make_chroot($file));
	if ($text) {
		print &ui_table_start(undef, "width=100%", 2);
		print &ui_table_row(undef,
			"<pre>".&html_escape($text)."</pre>", 2);
		print &ui_table_end();
		}
	else {
		print "$text{'text_none'}<p>\n";
		}
	}

&ui_print_footer(($tv eq "master" ? "edit_master.cgi" :
	 $tv eq "forward" ? "edit_forward.cgi" : "edit_slave.cgi").
	"?zone=$in{'zone'}&view=$in{'view'}", $text{'master_return'});
