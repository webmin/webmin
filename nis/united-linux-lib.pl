# united-linux-lib.pl
# NIS functions for United Linux NIS client and server

$yp_makefile = "/var/yp/Makefile";
$ypserv_conf = "/etc/ypserv.conf";
$pid_file = "/var/run/ypserv.pid";

# get_nis_support()
# Returns 0 for no support, 1 for client only, 2 for server and 3 for both
sub get_nis_support
{
local $rv;
$rv += 1 if (&has_command("ypbind"));
$rv += 2 if (&has_command("ypserv"));
return $rv;
}

# get_client_config()
# Returns a hash ref containg details of the client's NIS settings
sub get_client_config
{
local $nis;
open(CONF, $config{'client_conf'});
while(<CONF>) {
	s/\r|\n//g;
	s/#.*$//g;
	if (/^\s*domain\s*(\S+)\s*broadcast/i) {
		$nis->{'broadcast'}++;
		}
	elsif (/^\s*domain\s*(\S+)\s*server\s*(\S+)/i) {
		push(@{$nis->{'servers'}}, $2);
		}
	elsif (/^\s*ypserver\s*(\S+)/) {
		push(@{$nis->{'servers'}}, $1);
		}
	}
close(CONF);
open(DOMAIN, "/etc/defaultdomain");
chop($nis->{'domain'} = <DOMAIN>);
close(DOMAIN);
return $nis;
}

# save_client_config(&config)
# Saves and applies the NIS client configuration in the give hash.
# Returns an error message if any, or undef on success.
sub save_client_config
{
# Save the config file
&open_tempfile(CONF, ">$config{'client_conf'}");
if ($_[0]->{'domain'}) {
	if ($_[0]->{'broadcast'}) {
		&print_tempfile(CONF, "domain $_[0]->{'domain'} broadcast\n");
		}
	else {
		local @s = @{$_[0]->{'servers'}};
		&print_tempfile(CONF, "domain $_[0]->{'domain'} server ",shift(@s),"\n");
		foreach $s (@s) {
			&print_tempfile(CONF, "ypserver $s\n");
			}
		}
	}
&close_tempfile(CONF);

# Stop the init script
local $init = &init_script("ypbind");
&system_logged("$init stop >/dev/null 2>&1");

# Save domain name
if ($_[0]->{'domain'}) {
	&open_tempfile(DOMAIN, ">/etc/defaultdomain");
	&print_tempfile(DOMAIN, $_[0]->{'domain'},"\n");
	&close_tempfile(DOMAIN);
	}
else {
	unlink("/etc/defaultdomain");
	}

# Start the init script
if ($_[0]->{'domain'}) {
	local $out = &backquote_logged("$init start 2>&1");
	if ($?) { return "<pre>$out</pre>"; }
	}
return undef;
}

@nis_files = ( "passwd", "shadow", "group", "gshadow", "adjunct",
	       "aliases", "ethers", "bootparams", "hosts", "networks",
	       "printcap", "protocols", "publickeys", "rpc", "services",
	       "netgroup", "netid", "auto_master", "auto_home",
	       "auto_local", "timezone", "locale", "netmasks" );

@nis_tables = ( "passwd", "group", "hosts", "rpc", "services", "netid",
		"protocols", "netgrp", "mail", "shadow", "publickey",
		"networks", "ethers", "bootparams", "printcap", "amd.home",
		"auto.master", "auto.home", "auto.local", "passwd.adjunct",
		"timezone", "locale", "netmasks" );

# show_server_config()
# Display a form for editing NIS server options
sub show_server_config
{
local ($var, $rule) = &parse_yp_makefile();
if ($var->{'YPPWDDIR'}->{'value'} =~ /^\$\(shell/) {
	# Value comes from the ypserv config file
	local %ypserv;
	&read_env_file("/etc/sysconfig/ypserv", \%ypserv);
	$var->{'YPPWDDIR'}->{'value'} = $ypserv{'YPPWD_SRCDIR'};
	}

local $boot = &init::action_status("ypserv");
print "<tr> <td><b>$text{'server_boot'}</b></td>\n";
printf "<td><input type=radio name=boot value=1 %s> %s\n",
	$boot == 2 ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=boot value=0 %s> %s</td>\n",
	$boot == 2 ? '' : 'checked', $text{'no'};

local $dom = $var->{'LOCALDOMAIN'}->{'value'};
print "<td><b>$text{'server_domain'}</b></td>\n";
printf "<td><input type=radio name=domain_auto value=1 %s> %s\n",
	$dom =~ /`.*domainname`/ ? 'checked' : '', $text{'server_domain_auto'};
printf "<input type=radio name=domain_auto value=0 %s>\n",
	$dom =~ /`.*domainname`/ ? '' : 'checked';
printf "<input name=domain size=20 value='%s'></td> </tr>\n",
	$dom =~ /`.*domainname`/ ? '' : $dom;

print "<tr> <td><b>$text{'server_type'}</b></td>\n";
printf "<td colspan=3><input type=radio name=type value=1 %s> %s\n",
	$config{'slave'} ? '' : 'checked', $text{'server_master'};
printf "<input type=radio name=type value=0 %s> %s\n",
	$config{'slave'} ? 'checked' : '', $text{'server_slave'};
printf "<input name=slave size=30 value='%s'></td> </tr>\n", $config{'slave'};

print "</table></td></tr></table><p>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'server_mheader'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'server_dns'}</b></td>\n";
printf "<td><input type=radio name=b value='-b' %s> %s\n",
	$var->{'B'}->{'value'} eq '-b' ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=b value='' %s> %s</td>\n",
	$var->{'B'}->{'value'} eq '-b' ? '' : 'checked', $text{'no'};

print "<td><b>$text{'server_push'}</b></td>\n";
printf "<td><input type=radio name=nopush value=false %s> %s\n",
	$var->{'NOPUSH'}->{'value'} eq 'true' ? '' : 'checked', $text{'yes'};
printf "<input type=radio name=nopush value=true %s> %s</td> </tr>\n",
	$var->{'NOPUSH'}->{'value'} eq 'true' ? 'checked' : '', $text{'no'};

local %inall;
map { $inall{$_}++ } split(/\s+/, $rule->{'all'}->{'value'});
print "<tr> <td rowspan=2 valign=top><b>$text{'server_tables'}</b></td>\n";
print "<td rowspan=2><select multiple size=5 name=tables>\n";
foreach $t (grep { $rule->{$_} } @nis_tables) {
	printf "<option value=%s %s>%s</option>\n",
		$t, $inall{$t} ? 'selected' : '', $t;
	}
print "</select></td>\n";

print "<td><b>$text{'server_minuid'}</b></td>\n";
printf "<td><input name=minuid size=10 value='%s'></td> </tr>\n",
	$var->{'MINUID'}->{'value'};

print "<td><b>$text{'server_mingid'}</b></td>\n";
printf "<td><input name=mingid size=10 value='%s'></td> </tr>\n",
	$var->{'MINGID'}->{'value'};

print "<tr> <td><b>$text{'server_slaves'}</b></td>\n";
open(SLAVES, "/var/yp/ypservers");
while(<SLAVES>) {
	s/\s//g;
	push(@slaves, $_) if ($_);
	}
close(SLAVES);
printf "<td colspan=3><input name=slaves size=60 value='%s'></td> </tr>\n",
	join(" ", @slaves);

print "</table></td></tr></table><p>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'server_fheader'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

local $i = 0;
foreach $t (@nis_files) {
	local $f = &expand_vars($var->{uc($t)}->{'value'}, $var);
	next if (!$f);
	print "<tr>\n" if ($i%2 == 0);
	print "<td><b>",&text('server_file', $text{"desc_$t"} ? $text{"desc_$t"}
							      : $t),"</b></td>\n";
	print "<td><input name=$t size=30 value='$f'></td>\n";
	print "</tr>\n" if ($i++%2 == 1);
	}
}

# parse_server_config()
# Parse and save the NIS server options
sub parse_server_config
{
local ($var, $rule) = &parse_yp_makefile();
if ($var->{'YPPWDDIR'}->{'value'} =~ /^\$\(shell/) {
	# Value comes from the ypserv config file
	local %ypserv;
	&read_env_file("/etc/sysconfig/ypserv", \%ypserv);
	$var->{'YPPWDDIR'}->{'value'} = $ypserv{'YPPWD_SRCDIR'};
	}

$in{'minuid'} =~ /^\d+$/ || &error($text{'server_eminuid'});
$in{'mingid'} =~ /^\d+$/ || &error($text{'server_emingid'});
$in{'domain_auto'} || $in{'domain'} =~ /^[A-Za-z0-9\.\-]+$/ ||
	&error($text{'server_edomain'});
$in{'type'} || &to_ipaddress($in{'slave'}) ||
	&to_ip6address($in{'slave'}) || &error($text{'server_eslave'});
&update_makefile($var->{'MINUID'}, $in{'minuid'});
&update_makefile($var->{'MINGID'}, $in{'mingid'});
&update_makefile($var->{'NOPUSH'}, $in{'nopush'});
&update_makefile($var->{'B'}, $in{'b'});
&update_makefile($var->{'LOCALDOMAIN'}, $in{'domain_auto'} ? "`domainname`"
							   : $in{'domain'});
&update_makefile($rule->{'all'}, join(" ", split(/\0/, $in{'tables'})), "");

foreach $t (@nis_files) {
	local $old = &expand_vars($var->{uc($t)}->{'value'}, $var);
	next if (!$old);
	if ($old ne $in{$t}) {
		$in{$t} =~ /\S/ || &error(&text('server_efile', $text{"desc_$t"}));
		&update_makefile($var->{uc($t)}, $in{$t});
		}
	}
&flush_file_lines();

&open_tempfile(SLAVES, ">/var/yp/ypservers");
foreach $s (split(/\s+/, $in{'slaves'})) {
	&print_tempfile(SLAVES, "$s\n");
	}
&close_tempfile(SLAVES);

local $init1 = &init_script("ypserv");
local $init2 = &init_script("yppasswdd");
local $init3 = &init_script("ypxfrd");
&system_logged("$init1 stop >/dev/null 2>&1");
&system_logged("$init2 stop >/dev/null 2>&1");
&system_logged("$init3 stop >/dev/null 2>&1");
if ($in{'boot'}) {
	&init::enable_at_boot("ypserv");
	&init::enable_at_boot("yppasswdd");
	&init::enable_at_boot("ypxfrd");
	}
else {
	&init::disable_at_boot("ypserv");
	&init::disable_at_boot("yppasswdd");
	&init::disable_at_boot("ypxfrd");
	}
if ($in{'boot'}) {
	&system_logged("$init1 start >/dev/null 2>&1");
	&system_logged("$init2 start >/dev/null 2>&1");
	&system_logged("$init3 start >/dev/null 2>&1");
	}
if ($in{'type'}) {
	# Master server
	delete($config{'slave'});
	&apply_table_changes() if ($in{'boot'});
	}
else {
	$out = &backquote_logged("/usr/lib/yp/ypinit -s $in{'slave'} 2>&1");
	if ($?) { &error("<tt>$out</tt>"); }
	$config{'slave'} = $in{'slave'};
	}
&write_file("$module_config_directory/config", \%config);
}

# get_server_mode()
# Returns 0 if the NIS server is inactive, 1 if active as a master, or 2 if
# active as a slave.
sub get_server_mode
{
if (&init::action_status("ypserv") != 2) {
	return 0;
	}
elsif ($config{'slave'}) {
	return 2;
	}
else {
	return 1;
	}
}

# list_nis_tables()
# Returns a list of structures of all NIS tables
sub list_nis_tables
{
local ($var, $rule) = &parse_yp_makefile();
if ($var->{'YPPWDDIR'}->{'value'} =~ /^\$\(shell/) {
	# Value comes from the ypserv config file
	local %ypserv;
	&read_env_file("/etc/sysconfig/ypserv", \%ypserv);
	$var->{'YPPWDDIR'}->{'value'} = $ypserv{'YPPWD_SRCDIR'};
	}
local @rv;
local $dom = $var->{'LOCALDOMAIN'}->{'value'};
chop($dom = `domainname`) if ($dom =~ /`.*domainname`/);
local %file;
map { $file{uc($_)} = &expand_vars($var->{uc($_)}->{'value'}, $var) } @nis_files;
local @all = split(/\s+/, $rule->{'all'}->{'value'});
foreach $t (@all) {
	local $table = { 'table' => $t,
		         'index' => scalar(@rv),
		         'domain' => $dom };
	if ($t eq "passwd") {
		if ($var->{'MERGE_PASSWD'}->{'value'} eq 'true') {
			$table->{'type'} = 'passwd_shadow';
			$table->{'files'} = [ $file{'PASSWD'}, $file{'SHADOW'} ];
			}
		elsif (&indexof('shadow', @all) >= 0) {
			# Show separate shadow and passwd tables as one table
			$table->{'type'} = 'passwd_shadow_full';
			$table->{'files'} = [ $file{'PASSWD'}, $file{'SHADOW'} ];
			@all = grep { $_ ne 'shadow' } @all;
			}
		else {
			$table->{'type'} = 'passwd';
			$table->{'files'} = [ $file{'PASSWD'} ];
			}
		}
	elsif ($t eq "group") {
		if ($var->{'MERGE_GROUP'}->{'value'} eq 'true') {
			$table->{'type'} = 'group_shadow';
			$table->{'files'} = [ $file{'GROUP'}, $file{'GSHADOW'} ];
			}
		else {
			$table->{'type'} = 'group';
			$table->{'files'} = [ $file{'GROUP'} ];
			}
		}
	elsif ($t eq "netgrp") {
		$table->{'type'} = "netgroup";
		$table->{'files'} = [ $file{'NETGROUP'} ];
		}
	elsif ($t eq "mail") {
		$table->{'type'} = "aliases";
		$table->{'files'} = [ $file{'ALIASES'} ];
		}
	else {
		$table->{'type'} = $t;
		$table->{'files'} = [ $file{uc($t)} ];
		}
	push(@rv, $table);
	}
return @rv;
}

# apply_table_changes()
# Do whatever is necessary for the table text files to be loaded into
# the NIS server
sub apply_table_changes
{
&system_logged("(cd /var/yp ; make) >/dev/null 2>&1 </dev/null");
}

sub extra_config_files
{
return ( "/etc/defaultdomain", "/var/yp/ypservers" );
}

1;

