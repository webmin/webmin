#!/usr/bin/perl
# Actually do a restore

require './itsecur-lib.pl';
&can_edit_error("restore");
&error_setup($text{'restore_err'});
&ReadParseMime();

# Validate inputs
if (!$in{'src_def'}) {
	if (-d $in{'src'}) {
		$in{'src'} .= "/firewall.zip";
		}
	-r $in{'src'} || &error_cleanup($text{'restore_esrc'});
	$file = $in{'src'};
	}
else {
	$in{'file'} || &error_cleanup($text{'restore_efile'});
	$file = &tempname();
	open(FILE, ">$file");
	print FILE $in{'file'};
	close(FILE);
	}
if (!$in{'pass_def'}) {
	$in{'pass'} || &error_cleanup($text{'backup_epass'});
	}
@what = split(/\0/, $in{'what'});
@what || &error_cleanup($text{'restore_ewhat'});
%what = map { $_, 1 } @what;

# Extract the zip file
$tempdir = &tempname();
mkdir($tempdir, 0700);
$pass = $in{'pass_def'} ? undef : "-P '$in{'pass'}'";
$out = &backquote_logged("(cd $tempdir && unzip $pass '$file') 2>&1 </dev/null");
&error_cleanup($text{'restore_epass2'}) if ($? && $out =~ /password/ &&
					    $in{'pass_def'});
&error_cleanup($text{'restore_epass'}) if ($? && $out =~ /password/);
&error_cleanup($text{'restore_etar'}) if ($?);

# Work out the new state
@rules = &list_rules(&if_exists("rules"));
@services = &list_services(&if_exists("services"));
@groups = &list_groups(&if_exists("groups"));
($natiface, @nats) = &get_nat(&if_exists("nat"));
@pats = &get_pat(&if_exists("pat"));
($spoofiface, @spoofs) = &get_spoof(&if_exists("spoof"));
($flood, $spoof) = &get_syn(&if_exists("syn"));
@times = &list_times(&if_exists("times"));

# Ensure that the new state would be consistent
%groups = map { $_->{'name'}, $_ } @groups;
%services = map { $_->{'name'}, $_ } @services;
%times = map { $_->{'name'}, $_ } @times;
foreach $r (@rules) {
	foreach $g (split(/\s+/, $r->{'source'}), split(/\s+/, $r->{'dest'})) {
		if ($g =~ /^\!?\@(.*)$/ && !$groups{$1}) {
			push(@cerrs, &text('restore_egroup', "$1",
					   $r->{'num'}));
			}
		}
	foreach $s (split(/,/, $r->{'service'})) {
		if ($s ne "*" && !$services{$s}) {
			push(@cerrs, &text('restore_eservice', $s,
					   $r->{'num'}));
			}
		}
	if (!$r->{'sep'} && $r->{'time'} ne "*" && !$times{$r->{'time'}}) {
		push(@cerrs, &text('restore_etime', $r->{'time'},
				   $r->{'num'}));
		}
	}
foreach $n (@nats) {
	if (!ref($n) && $n =~ /^\!?(.*)$/ && !$groups{$1}) {
		push(@cerrs, &text('restore_enat', $1));
		}
	}
foreach $p (@pats) {
	if (!$services{$p->{'service'}}) {
		push(@cerrs, &text('restore_epat', $p->{'service'}));
		}
	}
foreach $n (@nats) {
	if (!ref($n) && $n =~ /^\!?(.*)$/ && !$groups{$1}) {
		push(@cerrs, &text('restore_enat', $1));
		}
	}
if (@cerrs) {
	# Tell the user
	&header($text{'restore_title'}, "",
		undef, undef, undef, undef, &apply_button());
	print "<hr>\n";

	print "<p>$text{'restore_cerr'}<br>\n";
	print "<ul>\n";
	foreach $c (@cerrs) {
		print "<li>$c\n";
		}
	print "</ul>\n";

	print "<hr>\n";
	&footer("", $text{'index_return'});
	exit;
	}

# Copy to the config directory
&automatic_backup();
&lock_itsecur_files();
foreach $w (@what) {
	if ($w eq "ipsec") {
		# Copy ipsec config to proper location
		if (&has_ipsec() && -r "$tempdir/ipsec.conf") {
			&lock_file($ipsec::config{'file'});
			&lock_file($ipsec::config{'secrets'});
			system("cp $tempdir/ipsec.conf $ipsec::config{'file'}");
			system("cp $tempdir/ipsec.secrets $ipsec::config{'secrets'}");
			&unlock_file($ipsec::config{'file'});
			&unlock_file($ipsec::config{'secrets'});
			}
		}
	elsif ($w eq "users") {
		# Copy Webmin user files
		&lock_file("$config_directory/miniserv.users");
		&lock_file("$config_directory/webmin.acl");
		system("cp $tempdir/miniserv.users $config_directory/miniserv.users");
		system("cp $tempdir/webmin.acl $config_directory/webmin.acl");
		foreach $a (glob("$tempdir/*.acl")) {
			local $fn = $a;
			$fn =~ s/^.*\///;
			if ($fn ne "webmin.acl") {
				&lock_file("$module_config_directory/$fn");
				system("cp $a $module_config_directory/$fn");
				&unlock_file("$module_config_directory/$fn");
				}
			}
		&unlock_file("$config_directory/miniserv.users");
		&unlock_file("$config_directory/webmin.acl");
		&restart_miniserv();
		}
	elsif ($w eq "searches") {
		# Copy searches directory
		mkdir($searches_directory, 0755);
		system("cp $tempdir/searches/* $searches_directory >/dev/null 2>&1");
		}
	elsif ($w eq "config") {
		# Update module config - except system type
		local %newconfig;
		&read_file("$tempdir/config", \%newconfig);
		$newconfig{'type'} = $config{'type'};
		&write_file("$module_config_directory/config", \%newconfig);
		}
	else {
		if (-r "$tempdir/$w") {
			system("cp $tempdir/$w $module_config_directory");
			}
		}
	}
&unlock_itsecur_files();

# Tell the user
&header($text{'restore_title'}, "",
	undef, undef, undef, undef, &apply_button());
print "<hr>\n";

print "<p>",&text('restore_done'),"<p>\n";
&cleanup();

print "<hr>\n";
&footer("", $text{'index_return'});
&remote_webmin_log("restore", undef, $in{'src_def'} ? undef : $in{'src'});

sub error_cleanup
{
&cleanup();
&error(@_);
}

sub cleanup
{
unlink($file) if ($in{'src_def'});
system("rm -rf $tempdir") if ($tempdir);
}

sub if_exists
{
return -r "$tempdir/$_[0]" && $what{$_[0]} ? "$tempdir/$_[0]" : undef;
}

