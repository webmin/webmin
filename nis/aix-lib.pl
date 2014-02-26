# aix-lib.pl
# NIS functions for aix, based on the solaris library

$binding_dir = "/var/yp/binding";
$yp_makefile = "/var/yp/Makefile";

# get_nis_support()
# Returns 0 for no support, 1 for client only, 2 for server and 3 for both
sub get_nis_support
{
local $rv;
local $result;

$result=`lssrc -s ypbind |grep -q active && echo ok`;

$rv += 1 if ($result == "ok");

$result=`lssrc -s ypserv |grep -q active && echo ok`;
$rv += 2 if ($result == "ok");
return $rv;
}

# get_client_config()
# Returns a hash ref containg details of the client's NIS settings
sub get_client_config
{
local $nis;
open(DOM, "/usr/bin/domainname |") ||die("could not run /usr/bin/domainname : $!");
chomp($nis->{'domain'} = <DOM>);
close(DOM);
if ($nis->{'domain'}) {
	if (open(SRV, "$binding_dir/$nis->{'domain'}/ypservers")) {
		while(<SRV>) {
			s/\r|\n//g;
			push(@{$nis->{'servers'}}, $_);
			}
		close(SRV);
		}
	else {
		$nis->{'broadcast'} = 1;
		}
	}
return $nis;
}

# save_client_config(&config)
# Saves and applies the NIS client configuration in the give hash.
# Returns an error message if any, or undef on success.
sub save_client_config
{
if ($_[0]->{'domain'}) {
	# Check if the servers are in /etc/hosts
	local @s = @{$_[0]->{'servers'}};
	&foreign_require("net", "net-lib.pl");
	foreach $s (@s) {
		local $found = 0;
		foreach $h (&foreign_call("net", "list_hosts")) {
			$found++ if (&indexof($s, @{$h->{'hosts'}}) >= 0);
			}
		return &text("client_ehosts", $s) if (!$found);
		}

	# Write the files
	&logged_system("/usr/bin/domainname \"$_[0]->{'domain'}\"");
	mkdir("$binding_dir/$_[0]->{'domain'}", 0755);
	if (@s) {
		&open_tempfile(SRV, ">$binding_dir/$_[0]->{'domain'}/ypservers");
		foreach $s (@s) {
			&print_tempfile(SRV, "$s\n");
			}
		&close_tempfile(SRV);
		}
	else {
		unlink("$binding_dir/$_[0]->{'domain'}/ypservers");
		}
	}
else {
	&logged_system("/usr/bin/domainname ''");
	}

# Apply by running ypstop and ypstart
&system_logged("(stopsrc -s ypserv ; /usr/bin/domainname \"$_[0]->{'domain'}\" ; startsrc -s ypserv ) > /dev/null 2>&1 ");
sleep(2);
if ($_[0]->{'domain'}) {
	local $out = `ypwhich 2>&1`;
	if ($? || $out =~ /not\s+bound/i || $out =~ /can't\s+communicate/i) {
		system("(stopsrc -s ypserv) >/dev/null 2>&1");
		return $text{'client_eypwhich'};
		}
	}
}

@nis_tables = ( "passwd", "group", "hosts", "ethers", "networks", "rpc",
	        "services", "protocols", "netgroup", "bootparams", "aliases",
		"publickey", "netid", "netmasks", "c2secure", "timezone",
		"auto.master", "auto.home" );

# show_server_config()
# Display a form for editing NIS server options
sub show_server_config
{
local ($var, $rule) = &parse_yp_makefile();
local $dom = `domainname`; chop($dom);

print "<tr> <td><b>$text{'server_boot'}</b></td> <td>\n";
if ($dom && -d "/var/yp/$dom") {
	print "<i>$text{'server_already'}</i>\n";
	}
else {
	print "<input type=radio name=boot value=1 > $text{'yes'}\n";
	print "<input type=radio name=boot value=0 checked > $text{'no'}\n";
	}
print "</td>\n";

print "<td><b>$text{'server_domain'}</b></td>\n";
printf "<td><input type=radio name=domain_def value=1 %s> %s\n",
	$dom ? '' : 'checked', $text{'server_none'};
printf "<input type=radio name=domain_def value=0 %s>\n",
	$dom ? 'checked' : '';
printf "<input name=domain size=35 value='%s'></td> </tr>\n", $dom;

print "<tr> <td><b>$text{'server_type'}</b></td>\n";
printf "<td colspan=3><input type=radio name=type value=1 %s> %s\n",
	$config{'slave'} ? '' : 'checked', $text{'server_master'};
printf "<input type=radio name=type value=0 %s> %s\n",
	$config{'slave'} ? 'checked' : '', $text{'server_slave'};
printf "<input name=slave size=30 value='%s'></td> </tr>\n", $config{'slave'};

print "<tr> <td colspan=4><i>$text{'server_aix'}</i></td> </tr>\n";

print "</table></td></tr></table><p>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'server_mheader'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

local %inall;
local @all = split(/\s+/, $rule->{'all'}->{'value'});
map { $inall{$_}++ } @all;
print "<tr> <td rowspan=4 valign=top><b>$text{'server_tables'}</b></td>\n";
print "<td rowspan=4><select multiple size=6 name=tables>\n";
foreach $t (&unique(@nis_tables, @all)) {
	printf "<option value=%s %s>%s</option>\n",
		$t, $inall{$t} ? 'selected' : '', $t;
	}
print "</select></td>\n";

print "<td><b>$text{'server_dns'}</b></td>\n";
printf "<td><input type=radio name=b value='-b' %s> %s\n",
	$var->{'B'}->{'value'} eq '-b' ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=b value='' %s> %s</td> </tr>\n",
	$var->{'B'}->{'value'} eq '-b' ? '' : 'checked', $text{'no'};

print "<tr> <td><b>$text{'server_push'}</b></td>\n";
printf "<td><input type=radio name=nopush value='\"\"' %s> %s\n",
	$var->{'NOPUSH'}->{'value'} eq 'true' ? '' : 'checked', $text{'yes'};
printf "<input type=radio name=nopush value=true %s> %s</td> </tr>\n",
	$var->{'NOPUSH'}->{'value'} eq 'true' ? 'checked' : '', $text{'no'};

print "<tr> <td><b>$text{'server_dir'}</b></td>\n";
printf "<td><input name=dir size=30 value='%s'> %s</td> </tr>\n",
	$var->{'DIR'}->{'value'}, &file_chooser_button("dir", 0);

print "<tr> <td><b>$text{'server_pwdir'}</b></td>\n";
printf "<td><input name=pwdir size=30 value='%s'> %s</td> </tr>\n",
	$var->{'PWDIR'}->{'value'}, &file_chooser_button("pwdir", 0);
}

# parse_server_config()
# Parse and save the NIS server options
sub parse_server_config
{
local ($var, $rule) = &parse_yp_makefile();
$in{'domain_def'} || $in{'domain'} =~ /^[A-Za-z0-9\.\-\_]+$/ ||
	&error(&text('server_edomain', $in{'domain'}));
if ($in{'boot'} && $in{'domain_def'}) {
	&error($text{'server_ebootdom'});
	}
$in{'type'} || &to_ipaddress($in{'slave'}) ||
	&to_ip6address($in{'slave'}) || &error($text{'server_eslave'});
-d $in{'dir'} || &error($text{'server_edir'});
-d $in{'pwdir'} || &error($text{'server_epwdir'});
&update_makefile($var->{'NOPUSH'}, $in{'nopush'});
&update_makefile($var->{'B'}, $in{'b'});
&update_makefile($rule->{'all'}, join(" ", split(/\0/, $in{'tables'})), "");
&update_makefile($var->{'DIR'}, $in{'dir'});
&update_makefile($var->{'PWDIR'}, $in{'pwdir'});
&flush_file_lines();

if ($in{'domain_def'}) {
	&system_logged("domainname \"\" >/dev/null 2>&1");
	}
else {
	local $old = `domainname`; chop($old);
	&system_logged("chypdom -B \"$in{'domain'}\"");
	&system_logged("domainname \"$in{'domain'}\" >/dev/null 2>&1");
	if ($in{'boot'}) {
		# Create the domain directory
		mkdir("/var/yp/$in{'domain'}", 0755);
		&system_logged("rm -f /var/yp/*.time");	# force a remake
		}
	}

if ($in{'type'}) {
	# Master server
	delete($config{'slave'});
	&apply_table_changes()
		if (!$in{'domain_def'} && -d "/var/yp/$in{'domain'}");
	}
else {
	local $temp = &transname();
	open(TEMP, ">$temp");
	print TEMP "n\ny\n";
	close(TEMP);
	$out = &backquote_logged("/usr/sbin/ypinit -s $in{'slave'} <$temp 2>&1");
	unlink($temp);
	if ($?) { &error("<tt>$out</tt>"); }
	$config{'slave'} = $in{'slave'};
	}
&write_file("$module_config_directory/config", \%config);
&system_logged("stopsrc -g yp >/dev/null 2>&1");
&system_logged("startsrc -g yp >/dev/null 2>&1");
}

# get_server_mode()
# Returns 0 if the NIS server is inactive, 1 if active as a master, or 2 if
# active as a slave.
sub get_server_mode
{
local $dom = `domainname`; chop($dom);
return !$dom ? 0 : $config{'slave'} ? 2 : 1;
}

# parse_yp_makefile()
# Returns hashes of makefile variables and rules
sub parse_yp_makefile
{
# First parse joined lines
local $lnum = 0;
local (@lines, $llast);
open(MAKE, $yp_makefile);
while(<MAKE>) {
	s/\r|\n//g;
	local $slash = (s/\\$//);
	s/#.*$//;
	if ($llast) {
		$llast->{'value'} .= " $_";
		$llast->{'eline'} = $lnum;
		}
	else {
		push(@lines, { 'value' => $_,
			       'line' => $lnum,
			       'eline' => $lnum });
		}
	$llast = $slash ? $lines[$#lines] : undef;
	$lnum++;
	}
close(MAKE);

# Then look for variables and rules
local ($i, %var, %rule);
for($i=0; $i<@lines; $i++) {
	if ($lines[$i]->{'value'} =~ /^\s*(\S+)\s*=\s*(.*)/) {
		# Found a variable
		$var{$1} = { 'name' => $1,
			     'value' => $2,
			     'type' => 0,
			     'line' => $lines[$i]->{'line'},
			     'eline' => $lines[$i]->{'eline'} };
		}
	elsif ($lines[$i]->{'value'} =~ /^\s*(\S+):\s*(.*)/) {
		# Found a makefile rule
		$rule{$1} = { 'name' => $1,
			      'value' => $2,
			      'type' => 1,
			      'code' => $lines[$i+1]->{'value'},
			      'line' => $lines[$i]->{'line'},
			      'eline' => $lines[$i+1]->{'eline'} };
		$i++;
		}
	}
return ( \%var, \%rule );
}

# expand_vars(string, &vars)
sub expand_vars
{
local $rv = $_[0];
while($rv =~ /^(.*)\$\(([A-Za-z0-9_]+)\)(.*)$/) {
	$rv = $1.$_[1]->{$2}->{'value'}.$3;
	}
return $rv;
}

# update_makefile(&old, value, [value]);
sub update_makefile
{
local $lref = &read_file_lines($yp_makefile);
local @n;
if ($_[0]->{'type'} == 0) {
	@n = ( "$_[0]->{'name'} = $_[1]" );
	}
else {
	@n = ( "$_[0]->{'name'}: $_[1]", $_[2] );
	}
splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1, @n);
}

# apply_table_changes()
# Do whatever is necessary for the table text files to be loaded into
# the NIS server
sub apply_table_changes
{
&system_logged("(cd /var/yp ; /usr/bin/make) >/dev/null 2>&1 </dev/null");
}

# list_nis_tables()
# Returns a list of structures of all NIS tables
sub list_nis_tables
{
local @rv;
local ($var, $rule) = &parse_yp_makefile();
local $dom = `domainname`; chop($dom);
local @all = split(/\s+/, $rule->{'all'}->{'value'});
foreach $t (@all) {
	local $table = { 'table' => $t,
		         'index' => scalar(@rv),
		         'domain' => $dom };
	local $rt = $rule->{"$t.time"};
	local @files = split(/\s+/, $rt->{'value'});
	@files = map { &expand_vars($_, $var) } @files;
	$table->{'files'} = \@files;
	$table->{'type'} = $t eq 'passwd' && @files > 1 ? 'passwd_shadow' :
			   $t;
	push(@rv, $table);
	}
return @rv;
}

sub show_server_security
{
}

sub parse_server_security
{
&system_logged("stopsrc -g yp  >/dev/null 2>&1");
&system_logged("startsrc -g yp >/dev/null 2>&1");
}

1;

