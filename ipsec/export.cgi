#!/usr/local/bin/perl
# export.cgi
# Actually do the export of a connection

require './ipsec-lib.pl';
&error_setup($text{'export_err'});
&ReadParse();

# Get the config lines
@conf = &get_config();
$conn = $conf[$in{'idx'}];
$lref = &read_file_lines($conn->{'file'});
@lines = map { "$_\n" } @$lref[$conn->{'line'} .. $conn->{'eline'}];

if ($in{'mode'} == 0) {
	# Just show on screen
	print "Content-type: text/plain\n\n";
	print @lines;
	}
else {
	# Save to file
	$in{'file'} || &error($text{'export_efile'});
	&open_tempfile(EXPORT, ">$in{'file'}", 1) ||
		&error(&text('export_esave', $!));
	&print_tempfile(EXPORT, @lines);
	&close_tempfile(EXPORT);

	# Tell the user
	&ui_print_header(undef, $text{'export_title'}, "");

	@st = stat($in{'file'});
	print "<p>",&text('export_done', "<tt>$conn->{'value'}</tt>",
		    	  "<tt>$in{'file'}</tt>", $st[7]),"<p>\n";

	&ui_print_footer("edit.cgi?idx=$in{'idx'}", $text{'edit_return'});
	}

