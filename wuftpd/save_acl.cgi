#!/usr/local/bin/perl
# save_acl.cgi
# Save access control options

require './wuftpd-lib.pl';
&error_setup($text{'acl_err'});
&ReadParse();
&lock_file($config{'ftpaccess'});
$conf = &get_ftpaccess();

# Save deny directives
for($i=0; defined($daddrs = $in{"daddrs_$i"}); $i++) {
	$dmsg = $in{"dmsg_$i"};
	next if (!$daddrs);
	$daddrs =~ /^\S+$/ || &error(&text('acl_edaddr', $daddrs));
	$daddrs !~ /^\|(\S+)$/ || -r $1 || &error(&text('acl_edfile', $1));
	$dmsg =~ /^\S+$/ && -r $dmsg || &error(&text('acl_edmsg', $dmsg));
	push(@deny, { 'name' => 'deny',
		      'values' => [ $daddrs, $dmsg ] } );
	}
&save_directive($conf, 'deny', \@deny);

# Save limit directives
for($i=0; defined($lclass = $in{"lclass_$i"}); $i++) {
	next if (!$lclass);
	$in{"ln_def_$i"} || $in{"ln_$i"} =~ /^\d+$/ ||
		&error(&text('acl_eln', $in{"ln_$i"}));
	$in{"ltimes_def_$i"} || $in{"ltimes_$i"} =~ /^\S+$/ ||
		&error(&text('acl_etimes', $in{"ltimes_$i"}));
	-r $in{"lmsg_$i"} || &error(&text('acl_elmsg', $in{"lmsg_$i"}));
	push(@limit,
	     { 'name' => 'limit',
	       'values' => [ $lclass,
			     $in{"ln_def_$i"} ? -1 : $in{"ln_$i"},
			     $in{"ltimes_def_$i"} ? 'Any' : $in{"ltimes_$i"},
			     $in{"lmsg_$i"} ] } );
	}
&save_directive($conf, 'limit', \@limit);

# Save file-limt and data-limit directives
for($i=0; defined($fblimit = $in{"fblimit_$i"}); $i++) {
	next if (!$fblimit);
	$in{"fbcount_$i"} =~ /^\d+$/ ||
		&error(&text('acl_efbcount', $in{"fbcount_$i"}));
	local @v = $in{"fbraw_$i"} ? ('raw') : ();
	push(@v, $in{"fbinout_$i"}, $in{"fbcount_$i"}, $in{"fbclass_$i"});
	if ($fblimit eq 'file-limit') {
		push(@file_limit, { 'name' => 'file-limit',
				    'values' => \@v } );
		}
	else {
		push(@data_limit, { 'name' => 'data-limit',
				    'values' => \@v } );
		}
	}
&save_directive($conf, 'file-limit', \@file_limit);
&save_directive($conf, 'data-limit', \@data_limit);

# Save noretrieve directives
@class = &find_value("class", $conf);
for($i=0; defined($nfiles = $in{"nfiles_$i"}); $i++) {
	next if (!$nfiles);
	local @v = $in{"nrel_$i"} ? ('relative') : ();
	local @c = split(/\0/, $in{"nclass_$i"});
	push(@v, map { "class=$_" } @c) if (@c != @class);
	push(@v, split(/\s+/, $nfiles));
	push(@noretrieve, { 'name' => 'noretrieve',
			    'values' => \@v } );
	}
&save_directive($conf, 'noretrieve', \@noretrieve);

# Save allow-retrieve directives
for($i=0; defined($afiles = $in{"afiles_$i"}); $i++) {
	next if (!$afiles);
	local @v = $in{"arel_$i"} ? ('relative') : ();
	local @c = split(/\0/, $in{"aclass_$i"});
	push(@v, map { "class=$_" } @c) if (@c != @class);
	push(@v, split(/\s+/, $afiles));
	push(@allow_retrieve, { 'name' => 'allow-retrieve',
			        'values' => \@v } );
	}
&save_directive($conf, 'allow-retrieve', \@allow_retrieve);

# Save limit-time directives
if (!$in{'alimit_def'}) {
	$alimit = $in{'alimit'};
	$alimit =~ /^\d+$/ || &error(&text('acl_elimit', $alimit));
	}
if (!$in{'glimit_def'}) {
	$glimit = $in{'glimit'};
	$glimit =~ /^\d+$/ || &error(&text('acl_elimit', $glimit));
	}
if ($alimit && $alimit eq $glimit) {
	@limit_time = ( { 'name' => 'limit-time',
			  'values' => [ '*', $alimit ] } );
	}
else {
	if ($alimit) {
		push(@limit_time, ( { 'name' => 'limit-time',
				  'values' => [ 'anonymous', $alimit ] } ) );
		}
	if ($glimit) {
		push(@limit_time, ( { 'name' => 'limit-time',
				  'values' => [ 'guest', $glimit ] } ));
		}
	}
&save_directive($conf, 'limit-time', \@limit_time);

# Save loginfails and private directives
if ($in{'fails_def'}) {
	&save_directive($conf, 'loginfails', [ ]);
	}
else {
	$in{'fails'} =~ /^\d+$/ || &error(&text('acl_efails', $in{'fails'}));
	&save_directive($conf, 'loginfails',
			[ { 'name' => 'loginfails',
			    'values' => [ $in{'fails'} ] } ] );
	}
&save_directive($conf, 'private', 
			[ { 'name' => 'private',
			    'values' => [ $in{'private'} ] } ] );

&flush_file_lines();
&unlock_file($config{'ftpaccess'});
&webmin_log("acl", undef, undef, \%in);
&redirect("");

