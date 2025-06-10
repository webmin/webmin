#!/usr/local/bin/perl
# Apply a filter to email in some folder

require './filter-lib.pl';
&ReadParse();
&error_setup($text{'move_err'});

# Get the filter
@filters = &list_filters();
($filter) = grep { $_->{'index'} == $in{'idx'} } @filters;
$filter || &error($text{'save_egone'});

# Get the source and destination folders
@folders = &mailbox::list_folders();
$src = &mailbox::find_named_folder($in{'movefrom'}, \@folders);
$src || &error(&text('move_esrc', $in{'movefrom'}));
$dest = &file_to_folder($filter->{'action'}, \@folders);
$dest || &error(&text('move_edest', $filter->{'action'}));
&mailbox::folder_name($src) eq &mailbox::folder_name($dest) &&
	&error($text{'move_esame'});

&ui_print_unbuffered_header(undef, $text{'move_title'}, "");

# Find matching messages
if ($filter->{'condspam'}) {
	@fields = ( [ "X-Spam-Status", "Yes" ] );
	}
elsif ($filter->{'condlevel'}) {
	$stars = "*" x $filter->{'condlevel'};
	@fields = ( [ "X-Spam-Level", $stars ] );
	}
else {
	@fields = ( [ lc($filter->{'condheader'}),
		      $filter->{'condvalue'}, 1 ] );
	}
print &text('move_finding', &mailbox::folder_name($src)),"<br>\n";
@mails = &mailbox::mailbox_search_mail(\@fields, 1, $src, undef, 1);
if (!@mails) {
	print $text{'move_none'},"<p>\n";
	}
else {
	print &text('move_found', scalar(@mails)),"<p>\n";

	print &text('move_moving', scalar(@mails),
		    &mailbox::folder_name($dest)),"<br>\n";
	&mailbox::mailbox_move_mail($src, $dest, reverse(@mails));
	print $text{'move_done'},"<p>\n";
	}

if (defined(&theme_post_save_folder)) {
	&theme_post_save_folder($src);
	&theme_post_save_folder($dest);
	}

&ui_print_footer("", $text{'index_return'});

