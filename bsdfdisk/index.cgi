#!/usr/local/bin/perl
# Show a list of disks

use strict;
use warnings;
require './bsdfdisk-lib.pl';
our (%in, %text, %config, $module_name);

&ui_print_header(undef, $text{'index_title'}, "", "intro", 1, 1, 0,
		 &help_search_link("fdisk", "man"));

my $err = &check_fdisk();
if ($err) {
	&ui_print_endpage(&text('index_problem', $err));
	}

my @disks = &list_disks_partitions();
@disks = sort { $a->{'device'} cmp $b->{'device'} } @disks;
if (@disks) {
	print &ui_columns_start([ $text{'index_dname'},
                                  $text{'index_dsize'},
                                  $text{'index_dmodel'},
                                  $text{'index_dparts'} ]);
	foreach my $d (@disks) {
		print &ui_columns_row([
			"<a href='edit_disk.cgi?device=".&urlize($d->{'device'}).
			  "'>".&partition_description($d->{'device'})."</a>",
			&nice_size($d->{'size'}),
			$d->{'model'},
			scalar(@{$d->{'slices'}}),
			]);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'index_none'}</b> <p>\n";
	}

&ui_print_footer("/", $text{'index'});
