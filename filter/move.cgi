#!/usr/local/bin/perl
# Apply a filter to email in some folder

require './filter-lib.pl';
&foreign_require("mailbox", "mailbox-lib.pl");
&ReadParse();
&error_setup($text{'move_err'});

# Get the filter
@filters = &list_filters();
($filter) = grep { $_->{'index'} == $in{'idx'} } @filters;
$filter || &error($text{'save_egone'});

# Get the source and destination folders
@folders = &mailbox::list_folders();
$src = &mailbox::find_named_folder($in{'movefrom'}, \@folders);
$src || &error($text{'move_esrc'});
$dest = &mailbox::find_named_folder($filter->{'action'}, \@folders);
$dest || &error($text{'move_edest'});
&folder_name($src) eq &folder_name($dest) || &error($text{'move_esame'});
