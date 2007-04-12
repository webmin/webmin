#!/usr/local/bin/perl
# clone_mod.cgi
# Clone an existing usermin module under a new name

require './usermin-lib.pl';
&ReadParse();
&error_setup($text{'clone_err'});
$access{'umods'} || &error($text{'acl_ecannot'});

# Symlink the code directory
&get_usermin_miniserv_config(\%miniserv);
$src = $in{'mod'};
%minfo = &get_usermin_module_info($src);
$count = 2;
do {
	$dst = $src.$count;
	$count++;
	} while(-d "$miniserv{'root'}/$dst");
&symlink_logged($src, "$miniserv{'root'}/$dst") ||
	&error(&text('clone_elink', $!));

# Copy the config directory
mkdir("$config{'usermin_dir'}/$dst", 0755);
$out = &backquote_logged("( (cd $config{'usermin_dir'}/$src ; tar cf - .) | (cd $config{'usermin_dir'}/$dst ; tar xpf -) ) 2>&1");
if ($?) {
	&error(&text('clone_ecopy', $out));
	}
$in{'desc'} = &text('clone_desc', $minfo{'desc'}) if (!$in{'desc'});
&open_tempfile(CLONE, ">$config{'usermin_dir'}/$dst/clone");
&print_tempfile(CLONE, "desc=$in{'desc'}\n");
&close_tempfile(CLONE);

# Grant access to the clone to this user
&read_usermin_acl(undef, \%acl);
@mods = &unique(@{$acl{"user"}}, $dst);
&save_usermin_acl("user", \@mods);

if ($in{'cat'} ne '*') {
	# Assign to category
	&lock_file("$config{'usermin_dir'}/webmin.cats");
	&read_file("$config{'usermin_dir'}/webmin.cats", \%cats);
	$cats{$dst} = $in{'cat'};
	&write_file("$config{'usermin_dir'}/webmin.cats", \%cats);
	&unlock_file("$config{'usermin_dir'}/webmin.cats");
	}

&webmin_log("clone", undef, $in{'mod'}, { 'desc' => $minfo{'desc'},
					  'dst' => $dst,
					  'dstdesc' => $in{'desc'} });
&redirect("");

