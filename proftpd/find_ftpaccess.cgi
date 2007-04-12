#!/usr/local/bin/perl
# find_ftpaccess.cgi
# Finds all per-directory options files under the all the document roots

require './proftpd-lib.pl';
&ReadParse();
@rv = grep { -r $_ } @ftpaccess_files;
&error_setup($text{'find_err'});

if ($in{'from'}) {
	# Look under the given directory
	@dirs = ( $in{'dir'} );
	}
else {
	# Look in Anonymous sections
	$conf = &get_config();
	$anon = &find_directive("Anonymous", $conf);
	push(@dirs, $anon) if ($anon);
	foreach $v (&find_directive_struct("VirtualHost", $conf)) {
		$anon = &find_directive("Anonymous", $v->{'members'});
		push(@dirs, $anon) if ($anon);
		}
	&error($text{'find_eanon'}) if (!@dirs);
	}

foreach $d (@dirs) {
	if ($d =~ /^~(\S+)$/) {
		local @u = getpwnam($1);
		$d = $u[7];
		next if (!$u[7]);
		}
	open(FIND, "find '$d' -name .ftpaccess -print |");
	while(<FIND>) {
		s/\r|\n//g;
		push(@rv, $_);
		}
	close(FIND);
	}

# save results
$site{'ftpaccess'} = join(' ', &unique(@rv));
&write_file("$module_config_directory/site", \%site);
&redirect("ftpaccess.cgi");

