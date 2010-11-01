#!/usr/local/bin/perl
# save_share.cgi
# Save changes to a shared directory

require './dfs-lib.pl';
&error_setup($text{'save_err'});
use Socket;
&ReadParse();
@shlist = &list_shares();

if ($in{'delete'}) {
	# Redirect to deletion CGI
	&redirect("delete_share.cgi?idx=$in{'idx'}");
	exit;
	}

# check inputs
if ($in{directory} !~ /^\/.*/) {
	&error(&text('save_edirectory', $in{'directory'}));
	}
if (!(-d $in{directory})) {
	&error(&text('save_edirectory2', $in{'directory'}));
	}
@rolist = split(/\s+/, $in{rolist}); &check_hosts(@rolist);
@rwlist = split(/\s+/, $in{rwlist}); &check_hosts(@rwlist);
@rtlist = split(/\s+/, $in{rtlist}); &check_hosts(@rtlist);
if ($in{readwrite} == 2 && !@rwlist) {
	&error($text{'save_erw'});
	}
if ($in{readonly} == 2 && !@rolist) {
	&error($text{'save_ero'});
	}
if ($in{root} == 2 && !@rtlist) {
	&error($text{'save_eroot'});
	}

# Remove from the read-only list any hosts shared read-write as well
if ($in{readwrite} == 1) {
	$in{readonly} = 0;
	}
elsif ($in{readwrite} == 2) {
	foreach $rwh (@rwlist) {
		if (($idx = &indexof($rwh, @rolist)) != -1) {
			splice(@rolist, $idx, 1);
			}
		}
	if (@rolist == 0 && $in{readonly} == 2) {
		$in{readonly} = 0;
		}
	}

&lock_file($config{dfstab_file});
foreach $s (@shlist) {
	$taken = $s if ($s->{'dir'} eq $in{directory});
	}

if (defined($in{'idx'})) {
	$share = $shlist[$in{'idx'}];
	$olddir = $share->{'dir'};
	}
$share->{'dir'} = $in{'directory'};
$share->{'desc'} = $in{'desc'};
$share->{'type'} = 'nfs';

if (defined($in{'idx'})) {
	# Changing an existing share
	if ($taken && $taken->{'index'} != $in{'idx'}) {
		&error(&text('save_ealready', $in{'directory'}));
		}
	&parse_options($share->{'opts'});
	&set_options();
	$share->{'opts'} = &join_options();
	&modify_share($share);
	}
else {
	# Creating a new share
	if ($taken) {
		&error(&text('save_ealready', $in{'directory'}));
		}
	&set_options();
	$share->{'opts'} = &join_options();
	&create_share($share);
	}
&unlock_file($config{dfstab_file});
if (defined($in{'idx'})) {
	&webmin_log('modify', 'share', $olddir, \%in);
	}
else {
	&webmin_log('create', 'share', $share->{'dir'}, \%in);
	}
&redirect("");

# set_options()
# Fill in the options associative array
sub set_options
{
if ($in{readonly} == 0) { delete($options{"ro"}); }
elsif ($in{readonly} == 1) { $options{"ro"} = ""; }
elsif ($in{readonly} == 2) { $options{"ro"} = join(':', @rolist); }

if ($in{readwrite} == 0) { delete($options{"rw"}); }
elsif ($in{readwrite} == 1) { $options{"rw"} = ""; }
elsif ($in{readwrite} == 2) { $options{"rw"} = join(':', @rwlist); }

if ($in{root} == 0) { delete($options{"root"}); }
elsif ($in{root} == 2) { $options{"root"} = join(':', @rtlist); }

if (!$access{'simple'}) {
	if ($in{nosub}) { $options{"nosub"} = ""; }
	else { delete($options{"nosub"}); }

	if ($in{nosuid}) { $options{"nosuid"} = ""; }
	else { delete($options{"nosuid"}); }

	if ($in{secure}) { $options{"secure"} = ""; }
	else { delete($options{"secure"}); }

	if ($in{kerberos}) { $options{"kerberos"} = ""; }
	else { delete($options{"kerberos"}); }

	if ($in{'anon_m'} == 0) { delete($options{"anon"}); }
	elsif ($in{'anon_m'} == 1) { $options{"anon"} = -1; }
	else { $options{"anon"} = getpwnam($in{"anon"}); }

	if ($in{aclok}) { $options{"aclok"} = ""; }
	else { delete($options{"aclok"}); }

	if ($gconfig{'os_version'} >= 7) {
		if ($in{'public'}) { $options{'public'} = ""; }
		else { delete($options{'public'}); }
		if (!$in{'index_def'}) { $options{'index'} = $in{'index'}; }
		else { delete($options{'index'}); }
		}
	}
}

# check_hosts(host, host, ...)
# Die if any of the listed hosts does not exist
sub check_hosts
{
local $h;
if ($gconfig{'os_version'} < 7) {
	foreach $h (@_) {
		&to_ipaddress($h) || &to_ip6address($h) ||
			&error(&text('save_ehost', $h));
		}
	}
}


