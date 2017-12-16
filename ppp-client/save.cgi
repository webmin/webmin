#!/usr/local/bin/perl
# save_dialer.cgi
# Save, create or delete a dialer configuration

require './ppp-client-lib.pl';
&ReadParse();
$conf = &get_config();
$dialer = $conf->[$in{'idx'}] if (!$in{'new'});

&lock_file($config{'file'});
if ($in{'delete'}) {
	# Check for any dependencies?
	&error_setup($text{'save_err2'});
	foreach $c (@$conf) {
		if (lc($c->{'values'}->{'inherits'}) eq lc($dialer->{'name'})) {
			&error(&text('save_einherits',
				     &dialer_name($c->{'name'})));
			}
		}

	# Just delete this dialer
	&delete_dialer($dialer);
	}
else {
	# Validate and store basic inputs
	&error_setup($text{'save_err'});
	if (defined($in{'dialer'})) {
		$in{'dialer'} =~ /^[^\[\]]+$/ || &error($text{'save_ename'});
		$dialer->{'name'} = "Dialer $in{'dialer'}";
		}
	elsif (defined($in{'name'})) {
		$in{'name'} =~ /^[^\[\]]+$/ || &error($text{'save_ename'});
		$dialer->{'name'} = $in{'name'};
		}
	local ($clash) = grep { lc($_->{'name'}) eq
				lc($dialer->{'name'}) } @$conf;
	if ($clash && $clash ne $dialer) {
		&error($text{'save_eclash'});
		}
	&parse_opt("Phone", \&check_phone, $text{'save_ephone'});
	&parse_opt("Username");
	&parse_opt("Password");
	&parse_opt("Dial Prefix", \&check_phone, $text{'save_eprefix'});
	&parse_yes_no("Stupid Mode");
	for($i=1; $i<=4; $i++) {
		local $other = $in{"other_$i"};
		if ($other eq '') {
			&set_config("Phone$i");
			}
		else {
			&check_phone($other) || &error(&text('save_eother',$i));
			&set_config("Phone$i", $other);
			}
		}
	&set_config("Inherits", $in{'inherits_def'} ? undef : $in{'inherits'});

	# Validate and store modem options
	if ($in{'modem'} eq '*') {
		-r $in{'otherm'} || &error($text{'save_eotherm'});
		&set_config("Modem", $in{'otherm'});
		}
	elsif ($in{'modem'} eq '') {
		&set_config("Modem");
		}
	else {
		&set_config("Modem", $in{'modem'});
		}
	&parse_opt("Baud", \&check_number, $text{'save_ebaud'});
	for($i=1; $i<=9; $i++) {
		if ($in{"init_$i"} eq '') {
			&set_config("Init$i");
			}
		else {
			&set_config("Init$i", $in{"init_$i"});
			}
		}
	&parse_yes_no("Carrier Check");
	&parse_yes_no("Abort on Busy");
	&parse_opt("Dial Attempts", \&check_number, $text{'save_edial'});
	&parse_yes_no("Abort on No Dialtone");

	# Store networking options
	&parse_yes_no("Auto DNS");
	&parse_yes_no("Auto Reconnect");
	&parse_opt("Idle Seconds", \&check_number, $text{'save_eidle'});

	# Create or update the dialer
	if ($in{'new'}) {
		&create_dialer($dialer);
		}
	else {
		&update_dialer($dialer);
		}
	}
&unlock_file($config{'file'});
delete($dialer->{'values'}->{'password'});
&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "update",
	    "dialer", $dialer->{'name'}, $dialer->{'values'});
&redirect("");

# parse_opt(name, [checker, error])
sub parse_opt
{
local $n = lc("$_[0]");
if ($in{$n."_def"}) {
	&set_config($_[0]);
	}
else {
	local $func = $_[1];
	!$func || &$func($in{$n}) || &error($_[2]);
	&set_config($_[0], $in{$n});
	}
}

# parse_yes_no(name)
sub parse_yes_no
{
local $n = lc("$_[0]");
if ($in{$n} == 1) {
	&set_config($_[0], "on");
	}
elsif ($in{$n} == 0) {
	&set_config($_[0], "off");
	}
else {
	&set_config($_[0]);
	}
}

# set_config(name, [value])
sub set_config
{
local $n = lc("$_[0]");
if (defined($_[1])) {
	$dialer->{'values'}->{$n} = $_[1];
	$dialer->{'onames'}->{$n} = $_[0];
	}
else {
	delete($dialer->{'values'}->{$n});
	delete($dialer->{'onames'}->{$n});
	}
}

sub check_phone
{
return $_[0] =~ /^[0-9 \+\*\#A-Z]+$/;
}

sub check_number
{
return $_[0] =~ /^\d+$/;
}

