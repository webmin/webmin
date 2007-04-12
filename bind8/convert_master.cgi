#!/usr/local/bin/perl
# convert_master.cgi
# Convert a master zone into a slave

require './bind8-lib.pl';
&ReadParse();
$conf = &get_config();
if ($in{'view'} ne '') {
	$conf = $conf->[$in{'view'}]->{'members'};
	}
$zconf = $conf->[$in{'index'}];
&error_setup($text{'convert_err'});
&lock_file(&make_chroot($zconf->{'file'}));
$access{'slave'} || &error($text{'screate_ecannot1'});

# Change the type directive
&save_directive($zconf, 'type', [ { 'name' => 'type',
				    'values' => [ 'slave' ] } ], 1);

# Add a masters section
if ($config{'default_master'}) {
	@mdirs = map { { 'name' => $_ } } split(/\s+/, $config{'default_master'});
	&save_directive($zconf, 'masters', [ { 'name' => 'masters',
					       'type' => 1,
					       'members' => \@mdirs } ], 1);
	}

# Take out directives not allowed in slaves
&save_directive($zconf, 'allow-update', [ ], 1);

&flush_file_lines();
&unlock_file(&make_chroot($zconf->{'file'}));
&redirect("");

