#!/usr/local/bin/perl
# Create, save or delete MIME types

use strict;
use warnings;
require './nginx-lib.pl';
our (%text, %in, %access);
&ReadParse();
&error_setup($text{'mime_err'});
$access{'global'} || &error($text{'index_eglobal'});
&lock_all_config_files();
my $conf = &get_config();
my $http = &find("http", $conf);
my $types = &find("types", $http);
if (!$types) {
	&save_directive($http, [ ], [ { 'name' => 'types',
					'type' => 1,
					'members' => [ ] } ]);
	}

# Validate type name and values
my @words;
if ($in{'new'} || $in{'type'}) {
	$in{'name'} =~ /^[a-z0-9\.\_\-]+\/[a-z0-9\.\_\-]+$/ ||
		&error($text{'mime_ename'});
	@words = split(/\s+/, $in{'words'});
	@words || &error($text{'mime_ewords'});
	foreach my $w (@words) {
		$w =~ /^[a-z0-9\_\-]+$/ || &error($text{'mime_eword'});
		}
	}

# Check for clash
if ($in{'new'} || $in{'type'} && $in{'type'} ne $in{'name'}) {
	my ($clash) = grep { $_->{'name'} eq $in{'name'} }
			   @{$types->{'members'}};
	$clash && &error($text{'mime_eclash'});
	}

my @d;
if ($in{'new'}) {
	# Add a new type
	&save_directive($types, [ ], [ { 'name' => $in{'name'},
					 'words' => \@words } ]);
	}
elsif ($in{'type'}) {
	# Updating some type
	my ($old) = grep { $_->{'name'} eq $in{'type'} } @{$types->{'members'}};
	$old || &error($text{'mime_eold'});
	&save_directive($types, [ $old ], [ { 'name' => $in{'name'},
                                              'words' => \@words } ]);
	}
elsif ($in{'delete'}) {
	# Deleting some rows
	@d = split(/\0/, $in{'d'});
	@d || &error($text{'mime_enone'});
	my @del = ( );
	foreach my $name (@d) {
		my ($d) = grep { $_->{'name'} eq $name } @{$types->{'members'}};
		push(@del, $d) if ($d);
		}
	&save_directive($types, \@del, [ ]);
	}
else {
	# Nothing to do?
	&error($text{'mime_ebutton'});
	}

&flush_config_file_lines();
&unlock_all_config_files();
if ($in{'new'} || $in{'type'}) {
	&webmin_log($in{'new'} ? "create" : "modify", "mime", $in{'name'});
	}
elsif (@d == 1) {
	&webmin_log("delete", "mime", $d[0]);
	}
else {
	&webmin_log("delete", "mimes", scalar(@d));
	}
&redirect("edit_mime.cgi?search=".&urlize($in{'search'}));
