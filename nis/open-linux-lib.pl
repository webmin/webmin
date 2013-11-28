# open-linux-lib.pl
# NIS functions for caldera linux NIS client and server

$nis_config_dir = "/etc/nis";
$ypserv_conf = "/etc/ypserv.conf";
$pid_file = "/var/run/ypserv.pid";

# get_nis_support()
# Returns 0 for no support, 1 for client only, 2 for server and 3 for both
sub get_nis_support
{
local $rv;
$rv += 1 if (&has_command("ypbind"));
$rv += 2 if (-x "/usr/libexec/nis/rpc.ypserv");
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
		$nis->{'domain'} = $1;
		$nis->{'broadcast'}++;
		}
	elsif (/^\s*domain\s*(\S+)\s*server\s*(\S+)/i) {
		$nis->{'domain'} = $1;
		push(@{$nis->{'servers'}}, $2);
		}
	elsif (/^\s*ypserver\s*(\S+)/) {
		push(@{$nis->{'servers'}}, $1);
		}
	}
close(CONF);
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
if ($_[0]->{'domain'}) {
	&init::enable_at_boot("nis-client");
	}
else {
	&init::disable_at_boot("nis-client");
	}

# Apply by running the init script
local $init = &init_script("nis-client");
&system_logged("$init stop >/dev/null 2>&1");
if ($_[0]->{'domain'}) {
	&system_logged("domainname \"$_[0]->{'domain'}\"");
	local $out = &backquote_logged("$init start 2>&1");
	if ($?) { return "<pre>$out</pre>"; }
	$out = `ypwhich 2>&1`;
	if ($?) { return $text{'client_eypwhich'}; }
	}
else {
	&system_logged("domainname '' >/dev/null 2>&1");
	}
return undef;
}

# show_server_config()
# Display a form for editing NIS server options
sub show_server_config
{
local @domains;
opendir(DIR, $nis_config_dir);
foreach $f (readdir(DIR)) {
	push(@domains, $f) if ($f !~ /^\./ &&
			       -r "$nis_config_dir/$f/.nisupdate.conf");
	}
closedir(DIR);
@domains = ( "" ) if (!@domains);

local $boot = &init::action_status("nis-server");
print "<tr> <td valign=top><b>$text{'server_boot'}</b></td>\n";
printf "<td valign=top><input type=radio name=boot value=1 %s> %s\n",
	$boot == 2 ? 'checked' : '', $text{'yes'};
printf "<input type=radio name=boot value=0 %s> %s</td> </tr>\n",
	$boot == 2 ? '' : 'checked', $text{'no'};

local $n = 0;
foreach $d (@domains) {
	print "<tr> <td colspan=4><hr></td> </tr>\n";
	print "<input type=hidden name=old_$n value='$d'>\n";
	print "<tr> <td valign=top><b>$text{'server_domain'}</b></td>\n";
	printf "<td valign=top>".
	       "<input type=radio name=domain_def_$n value=1 %s> %s\n",
		$d ? '' : 'checked', $text{'server_none'};
	printf "<input type=radio name=domain_def_$n value=0 %s>\n",
		$d ? 'checked' : '';
	print "<input name=domain_$n size=30 value='$d'></td>\n";

	local @conf = &parse_nisupdate_conf(
		$d ? "$nis_config_dir/$d/.nisupdate.conf"
		   : "nisupdate.conf");
	print "<td valign=top><b>$text{'server_tables'}</b></td>\n";
	print "<td><select name=tables_$n size=6 multiple>\n";
	foreach $c (@conf) {
		printf "<option value=%s %s>%s</option>\n",
			$c->{'table'}, $c->{'active'} ? 'selected' : '',
			$c->{'table'};
		}
	print "</select></td> </tr>\n";

	$n++;
	}

}

# parse_server_config()
# Parse and save the NIS server options
sub parse_server_config
{
local ($n, $anydomains);
for($n=0; defined($in{"old_$n"}); $n++) {
	# Update the domain name directory
	$in{"domain_def_$n"} || $in{"domain_$n"} =~ /^[A-Za-z0-9\.\-]+$/ ||
		&error(&text('server_edomain', $in{"domain_$n"}));
	local $domain = $in{"domain_def_$n"} ? undef : $in{"domain_$n"};
	local $old = $in{"old_$n"};
	if (!$old && !$domain) {
		# No domain before, and none chosen
		next;
		}
	elsif (!$old && $domain) {
		# New domain added
		mkdir("$nis_config_dir/$domain", 0755);
		&system_logged("cp nisupdate.conf ".
			       "$nis_config_dir/$domain/.nisupdate.conf");
		}
	elsif ($old && !$domain) {
		# Domain taken away
		&system_logged("rm -rf $nis_config_dir/$old");
		next;
		}
	elsif ($old ne $domain) {
		# Domain renamed
		&rename_logged("$nis_config_dir/$old",
			       "$nis_config_dir/$domain");
		}
	$anydomains++;

	# Update the config file
	local $file = "$nis_config_dir/$domain/.nisupdate.conf";
	local @conf = &parse_nisupdate_conf($file);
	local $lref = &read_file_lines($file);
	local %table;
	map { $table{$_}++ } split(/\0/, $in{"tables_$n"});
	foreach $c (@conf) {
		if ($c->{'active'} && !$table{$c->{'table'}}) {
			# Need to deactivate a table
			splice(@$lref, $c->{'line'},
			       $c->{'eline'} - $c->{'line'} + 1,
			       map { "#$_" } @{$c->{'data'}});
			}
		elsif (!$c->{'active'} && $table{$c->{'table'}}) {
			# Need to activate a table
			splice(@$lref, $c->{'line'},
			       $c->{'eline'} - $c->{'line'} + 1,
			       @{$c->{'data'}});
			}
		}
	&flush_file_lines();
	}

# Start the NIS server and rebuild maps if needed
if ($in{'boot'}) {
	&init::enable_at_boot("nis-server");
	}
else {
	&init::disable_at_boot("nis-server");
	}
local $init = &init_script("nis-server");
&system_logged("$init stop >/dev/null 2>&1");
if ($anydomains && $in{'boot'}) {
	&system_logged("$init start >/dev/null 2>&1");
	}
&apply_table_changes();
}

# get_server_mode()
# Returns 0 if the NIS server is inactive, 1 if active as a master, or 2 if
# active as a slave.
sub get_server_mode
{
local $boot = &init::action_status("nis-server");
local $dc;
opendir(DIR, $nis_config_dir);
foreach $f (readdir(DIR)) {
	$dc++ if ($f !~ /^\./ && -r "$nis_config_dir/$f/.nisupdate.conf");
	}
closedir(DIR);
if ($boot != 2 || !$dc) {
	return 0;
	}
else {
	return 1;
	}
}

# parse_nisupdate_conf(file)
sub parse_nisupdate_conf
{
local @rv;
local $lnum = 0;
open(CONF, $_[0]);
while(<CONF>) {
	s/\r|\n//g;
	if (/^\s*(#*)(\s*\$rule{['"]([^"']+)['"]}.*)/) {
		local $text = $2;
		local $table = { 'table' => $3,
				 'active' => $1 eq '',
				 'data' => [ $2 ],
				 'line' => $lnum,
			 	 'eline' => $lnum };
		while(!/;\s*$/) {
			($_ = <CONF>) || last;
			s/^\s*#+//; s/\r|\n//g;
			push(@{$table->{'data'}}, $_);
			$text .= " $_";
			$lnum++;
			$table->{'eline'} = $lnum;
			}
		$table->{'value'} = $2 if ($text =~ /\$rule{['"]([^"']+)['"]}\s*=\s*["']([^"']+)["']/);
		push(@rv, $table);
		}
	$lnum++;
	}
close(CONF);
return @rv;
}

# list_nis_tables()
# Returns a list of structures of all NIS tables
sub list_nis_tables
{
local @rv;
opendir(DIR, $nis_config_dir);
foreach $d (readdir(DIR)) {
	push(@domains, $d) if ($d !~ /^\./ &&
			       -r "$nis_config_dir/$d/.nisupdate.conf");
	}
closedir(DIR);
foreach $d (@domains) {
	local @conf = &parse_nisupdate_conf(
			"$nis_config_dir/$d/.nisupdate.conf");
	foreach $t (@conf) {
		next if (!$t->{'active'});
		local $table = { 'table' => $t->{'table'},
				 'domain' => $d,
				 'index' => scalar(@rv) };
		if ($t->{'value'} =~ /^(\S+)\s+(\S+)/) {
			$table->{'files'} = [ map { "$nis_config_dir/$d/$_" }
					 	  split(/,/, $2) ];
			}
		if ($t->{'table'} eq 'passwd') {
			$table->{'type'} = 'passwd_shadow';
			}
		elsif ($t->{'table'} eq 'services') {
			$table->{'type'} = 'services2';
			}
		else {
			$table->{'type'} = $t->{'table'};
			}
		push(@rv, $table);
		}
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
local ($f, @rv);
opendir(DIR, $nis_config_dir);
foreach $f (readdir(DIR)) {
        push(@rv, "$nis_config_dir/$f/.nisupdate.conf") if ($f !~ /^\./);
        }
closedir(DIR);
push(@rv, "$nis_config_dir/nisupdate.conf");
return grep { -r $_ } @rv;
}

1;

