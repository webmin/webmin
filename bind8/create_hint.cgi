#!/usr/local/bin/perl
# create_hint.cgi
# Create a new root zone

require './bind8-lib.pl';
&ReadParse();
&error_setup($text{'hcreate_err'});
$access{'master'} || &error($text{'hcreate_ecannot'});
$access{'ro'} && &error($text{'master_ero'});

# Validate inputs
&allowed_zone_file(\%access, $in{'file'}) || &error($text{'hcreate_efile'});
open(FILE, ">>".&make_chroot($in{'file'})) || &error($text{'hcreate_efile2'});
close(FILE);

# Get the root server information
if ($in{'real'} == 1) {
	# Download from internic
	&ftp_download("rs.internic.net", "/domain/named.root", 
		      &make_chroot($in{'file'}));
	}
elsif ($in{'real'} == 2) {
	# Use webmin's copy
	system("cp ./db.cache ".&make_chroot($in{'file'})." 2>/dev/null");
	}
else {
	# Just check the existing file
	@recs = &read_zone_file(&make_chroot($in{'file'}), ".");
	&error($text{'mcreate_erecs'}) if (@recs < 2);
	}

# Create zone structure
$dir = { 'name' => 'zone',
	 'values' => [ '.' ],
	 'type' => 1,
	 'members' => [ { 'name' => 'type',
			  'values' => [ 'hint' ] },
			{ 'name' => 'file',
			  'values' => [ $in{'file'} ] }
		      ]
	};

# Add a new hint zone
$conf = &get_config();
&create_zone($dir, $conf, $in{'view'});
&webmin_log("create", "hint", ".", \%in);
&redirect("");

