# custom-lib.pl
# Functions for storing custom commands
# XXX variable in file editors
# XXX don't need quoting option
# XXX don't need upload type, or password, or text box, or option

do '../web-lib.pl';
&init_config();
%access = &get_module_acl();
do '../ui-lib.pl';

# list_commands()
# Returns a list of all custom commands
sub list_commands
{
local (@rv, $f);
local $mcd = $module_info{'usermin'} ? $config{'webmin_config'}
				     : $module_config_directory;
opendir(DIR, $mcd);
while($f = readdir(DIR)) {
	local %cmd;
	if ($f =~ /^(\d+)\.cmd$/) {
		# Read custom-command file
		$cmd{'file'} = "$mcd/$f";
		$cmd{'id'} = $1;
		open(FILE, $cmd{'file'});
		chop($cmd{'cmd'} = <FILE>);
		chop($cmd{'desc'} = <FILE>);
		local @o = split(/\s+/, <FILE>);
		$cmd{'user'} = $o[0];
		$cmd{'raw'} = int($o[1]);
		$cmd{'su'} = int($o[2]);
		$cmd{'order'} = int($o[3]);
		$cmd{'noshow'} = int($o[4]);
		$cmd{'usermin'} = int($o[5]);
		$cmd{'timeout'} = int($o[6]);
		$cmd{'clear'} = int($o[7]);
		}
	elsif ($f =~ /^(\d+)\.edit$/) {
		# Read file-editor file
		$cmd{'file'} = "$mcd/$f";
		$cmd{'id'} = $1;
		open(FILE, $cmd{'file'});
		chop($cmd{'edit'} = <FILE>);
		chop($cmd{'desc'} = <FILE>);
		chop($cmd{'user'} = <FILE>);
		chop($cmd{'group'} = <FILE>);
		chop($cmd{'perms'} = <FILE>);
		chop($cmd{'before'} = <FILE>);
		chop($cmd{'after'} = <FILE>);
		chop($cmd{'order'} = <FILE>);
		$cmd{'order'} = int($cmd{'order'});
		chop($cmd{'usermin'} = <FILE>);
		chop($cmd{'envs'} = <FILE>);
		}
	elsif ($f =~ /^(\d+)\.sql$/) {
		# Read SQL file
		$cmd{'file'} = "$mcd/$f";
		$cmd{'id'} = $1;
		open(FILE, $cmd{'file'});
		chop($cmd{'desc'} = <FILE>);
		chop($cmd{'type'} = <FILE>);
		chop($cmd{'db'} = <FILE>);
		chop($cmd{'user'} = <FILE>);
		chop($cmd{'pass'} = <FILE>);
		chop($cmd{'host'} = <FILE>);
		chop($cmd{'sql'} = <FILE>);
		$cmd{'sql'} =~ s/\t/\n/g;
		}
	if (%cmd) {
		# Read common stuff
		while(<FILE>) {
			s/\r|\n//g;
			local @a = split(/:/, $_, 5);
			push(@{$cmd{'args'}}, { 'name' => $a[0],
						'type' => $a[1],
						'opts' => $a[2],
						'quote' => $a[3],
						'desc' => $a[4] });
			}
		close(FILE);
		$cmd{'index'} = scalar(@rv);
		open(HTML, "$mcd/$cmd{'id'}.html");
		while(<HTML>) {
			$cmd{'html'} .= $_;
			}
		close(HTML);

		# Read cluster hosts file
		open(CLUSTER, "$mcd/$cmd{'id'}.hosts");
		while(<CLUSTER>) {
			s/\r|\n//g;
			push(@{$cmd{'hosts'}}, $_);
			}
		close(CLUSTER);

		push(@rv, \%cmd);
		}
	}
closedir(DIR);
return @rv;
}

# save_command(&command)
sub save_command
{
local $c = $_[0];
if ($c->{'edit'}) {
	# Save a file editor
	&open_lock_tempfile(FILE, ">$module_config_directory/$c->{'id'}.edit");
	&print_tempfile(FILE, $c->{'edit'},"\n");
	&print_tempfile(FILE, $c->{'desc'},"\n");
	&print_tempfile(FILE, $c->{'user'},"\n");
	&print_tempfile(FILE, $c->{'group'},"\n");
	&print_tempfile(FILE, $c->{'perms'},"\n");
	&print_tempfile(FILE, $c->{'before'},"\n");
	&print_tempfile(FILE, $c->{'after'},"\n");
	&print_tempfile(FILE, $c->{'order'},"\n");
	&print_tempfile(FILE, $c->{'usermin'},"\n");
	&print_tempfile(FILE, $c->{'envs'},"\n");
	}
elsif ($c->{'sql'}) {
	# Save an SQL command
	&open_lock_tempfile(FILE, ">$module_config_directory/$c->{'id'}.sql");
	&print_tempfile(FILE, $c->{'desc'},"\n");
	&print_tempfile(FILE, $c->{'type'},"\n");
	&print_tempfile(FILE, $c->{'db'},"\n");
	&print_tempfile(FILE, $c->{'user'},"\n");
	&print_tempfile(FILE, $c->{'pass'},"\n");
	&print_tempfile(FILE, $c->{'host'},"\n");
	local $sql = $c->{'sql'};
	$sql =~ s/\n/\t/g;
	&print_tempfile(FILE, $sql,"\n");
	}
else {
	# Save a custom command
	&open_lock_tempfile(FILE, ">$module_config_directory/$c->{'id'}.cmd");
	&print_tempfile(FILE, $c->{'cmd'},"\n");
	&print_tempfile(FILE, $c->{'desc'},"\n");
	&print_tempfile(FILE,
		   $c->{'user'}," ",int($c->{'raw'})," ",int($c->{'su'})," ",
		   int($c->{'order'})," ",int($c->{'noshow'})," ",
		   int($c->{'usermin'})," ",int($c->{'timeout'})," ",
		   int($c->{'clear'}),"\n");
	}


# Save parameters
foreach $a (@{$c->{'args'}}) {
	&print_tempfile(FILE, $a->{'name'},":",$a->{'type'},":",
	   $a->{'opts'},":",$a->{'quote'},":",$a->{'desc'},"\n");
	}
&close_tempfile(FILE);

# Save HTML description file
&lock_file("$module_config_directory/$c->{'id'}.html");
if ($cmd->{'html'}) {
	&open_tempfile(HTML, ">$module_config_directory/$c->{'id'}.html");
	&print_tempfile(HTML, $cmd->{'html'});
	&close_tempfile(HTML);
	}
else {
	unlink("$module_config_directory/$c->{'id'}.html");
	}
&unlock_file("$module_config_directory/$c->{'id'}.html");

# Save cluster hosts
&lock_file("$module_config_directory/$c->{'id'}.hosts");
if (@{$cmd->{'hosts'}}) {
	&open_tempfile(CLUSTER, ">$module_config_directory/$c->{'id'}.hosts");
	foreach my $h (@{$cmd->{'hosts'}}) {
		&print_tempfile(CLUSTER, "$h\n");
		}
	&close_tempfile(CLUSTER);
	}
else {
	unlink("$module_config_directory/$c->{'id'}.hosts");
	}
&unlock_file("$module_config_directory/$c->{'id'}.hosts");
}

# delete_command(&command)
sub delete_command
{
local $f = "$module_config_directory/$_[0]->{'id'}".
	   ($_[0]->{'edit'} ? ".edit" : $_[0]->{'sql'} ? ".sql" : ".cmd");
&lock_file($f);
unlink($f);
&unlock_file($f);

# Delete HTML file
local $hf = "$module_config_directory/$_[0]->{'id'}.html";
if (-r $hf) {
	&lock_file($hf);
	unlink($hf);
	&unlock_file($hf);
	}

# Delete cluster file
local $cf = "$module_config_directory/$_[0]->{'id'}.hosts";
if (-r $cf) {
	&lock_file($cf);
	unlink($cf);
	&unlock_file($cf);
	}
}

sub can_run_command
{
if ($module_info{'usermin'}) {
	# Only modules marked as for Usermin are considered
	return 0 if (!$_[0]->{'usermin'});

	# Check detailed access control list (if any)
	return 1 if (!$config{'access'});
	local @uinfo = @remote_user_info;
	@uinfo = getpwnam($remote_user) if (!@uinfo);
	local $l;
	foreach $l (split(/\t/, $config{'access'})) {
		if ($l =~ /^(\S+):\s*(.*)$/) {
			local ($user, $ids) = ($1, $2);
			local $applies;
			if ($user =~ /^\@(.*)$/) {
				# Check if user is in group
				local @ginfo = getgrnam($1);
				$applies++
				   if (@ginfo && ($ginfo[2] == $uinfo[3] ||
				       &indexof($remote_user,
						split(/\s+/, $ginfo[3])) >= 0));
				}
			elsif ($user eq $remote_user || $user eq "*") {
				$applies++;
				}
			if ($applies) {
				# Rule is for this user - check list
				local @ids = split(/\s+/, $ids);
				local $d;
				foreach $d (@ids) {
					return 1 if ($d eq '*' ||
						     $_[0]->{'id'} eq $d);
					return 0 if ("!".$_[0]->{'id'} eq $d);
					}
				return 0;
				}
			}
		}
	return 0;
	}
else {
	# Just use Webmin user's list of databases
	local $c;
	local $found;
	return 1 if ($access{'cmds'} eq '*');
	local @cmds = split(/\s+/, $access{'cmds'});
	foreach $c (@cmds) {
		$found++ if ($c eq $_[0]->{'id'});
		}
	return $cmds[0] eq '!' ? !$found : $found;
	}
}

# read_opts_file(file)
sub read_opts_file
{
local @rv;
local $file = $_[0];
if ($file !~ /^\// && $file !~ /\|\s*$/) {
	local @uinfo = getpwnam($remote_user);
	if (@uinfo) {
		$file = "$uinfo[7]/$file";
		}
	}
open(FILE, $file);
while(<FILE>) {
	s/\r|\n//g;
	if (/^"([^"]*)"\s+"([^"]*)"$/) {
		push(@rv, [ $1, $2 ]);
		}
	elsif (/^"([^"]*)"$/) {
		push(@rv, [ $1, $1 ]);
		}
	elsif (/^(\S+)\s+(\S.*)/) {
		push(@rv, [ $1, $2 ]);
		}
	else {
		push(@rv, [ $_, $_ ]);
		}
	}
close(FILE);
return @rv;
}

# show_params_inputs(&command, no-quote, editor-mode)
sub show_params_inputs
{
local ($cmd, $noquote, $editor) = @_;
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'edit_params'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'edit_name'}</b></td> ",
      "<td><b>$text{'edit_desc'}</b></td> <td><b>$text{'edit_type'}</b></td> ";
if (!$noquote) {
	print "<td><b>$text{'edit_quote'}</b></td> ";
	}
print "</tr>\n";
local @a = (@{$cmd->{'args'}}, { });
for(my $i=0; $i<@a; $i++) {
	print "<tr>\n";
	printf "<td><input name=name_$i size=10 value='%s'></td>\n",
		$a[$i]->{'name'};
	printf "<td><input name=desc_$i size=40 value='%s'></td>\n",
		&html_escape($a[$i]->{'desc'});
	print "<td><select name=type_$i>\n";
	for(my $j=0; $text{"edit_type$j"}; $j++) {
		next if ($editor &&
			 ($j == 7 || $j == 8 || $j == 10 || $j == 11));
		printf "<option value=%d %s>%s\n",
			$j, $a[$i]->{'type'} == $j ? "selected" : "",
			$text{"edit_type$j"};
		}
	print "</select>\n";
	print &ui_textbox("opts_$i", $a[$i]->{'opts'}, 20),"</td>\n";
	if (!$noquote) {
		print "<td>",&ui_yesno_radio("quote_$i",
					     int($a[$i]->{'quote'})),"</td>\n";
		}
	print "</tr>\n";
	}

print "</table></td></tr></table>\n";
}

# parse_params_inputs(&command)
sub parse_params_inputs
{
local ($cmd) = @_;
$cmd->{'args'} = [ ];
my ($i, $name);
for($i=0; defined($name = $in{"name_$i"}); $i++) {
	if ($name) {
		push(@{$cmd->{'args'}}, { 'name' => $name,
					  'desc' => $in{"desc_$i"},
					  'type' => $in{"type_$i"},
					  'quote' => int($in{"quote_$i"}),
					  'opts' => $in{"opts_$i"} });
		}
	}
}

# set_parameter_envs(&command, command-str, &uinfo)
# Sets $ENV variables based on parameter inputs, and returns the list of
# environment variable commands, the export commands, the command string,
# and the command string to display.
sub set_parameter_envs
{
local ($cmd, $str, $uinfo) = @_;
local $displaystr = $str;
local ($env, $export, @vals);
foreach my $a (@{$cmd->{'args'}}) {
	my $n = $a->{'name'};
	my $rv;
	if ($a->{'type'} == 0 || $a->{'type'} == 5 ||
	    $a->{'type'} == 6 || $a->{'type'} == 8) {
		$rv = $in{$n};
		}
	elsif ($a->{'type'} == 11) {
		$rv = $in{$n};
		$rv =~ s/\r//g;
		$rv =~ s/\n/ /g;
		}
	elsif ($a->{'type'} == 1 || $a->{'type'} == 2) {
		(@u = getpwnam($in{$n})) || &error($text{'run_euser'});
		$rv = $a->{'type'} == 1 ? $in{$n} : $u[2];
		}
	elsif ($a->{'type'} == 3 || $a->{'type'} == 4) {
		(@g = getgrnam($in{$n})) || &error($text{'run_egroup'});
		$rv = $a->{'type'} == 3 ? $in{$n} : $g[2];
		}
	elsif ($a->{'type'} == 7) {
		$rv = $in{$n} ? $a->{'opts'} : "";
		}
	elsif ($a->{'type'} == 9) {
		local $found;
		foreach my $l (&read_opts_file($a->{'opts'})) {
			$found++ if ($l->[0] eq $in{$n});
			}
		$found || &error($text{'run_eopt'});
		$rv = $in{$n};
		}
	elsif ($a->{'type'} == 10) {
		$in{$n} || &error($text{'run_eupload'});
		if ($in{$n."_filename"} =~ /([^\/\\]+$)/ && $1) {
			$rv = &transname("$1");
			}
		else {
			$rv = &transname();
			}
		&open_tempfile(TEMP, ">$rv");
		&print_tempfile(TEMP, $in{$n});
		&close_tempfile(TEMP);
		chown($uinfo->[2], $uinfo->[3], $rv);
		push(@unlink, $rv);
		}
	$ENV{$n} = $rv;
	$env .= "$n='$rv'\n";
	$export .= " $n";
	if ($a->{'quote'}) {
		$str =~ s/\$$n/"\$$n"/g;
		$displaystr =~ s/\$$n/"$rv"/g;
		}
	else {
		$displaystr =~ s/\$$n/$rv/g;
		}
	push(@vals, $rv);
	}
return ($env, $export, $str, $displaystr, \@vals);
}

# list_dbi_drivers()
# Returns a list of DBI driver details, which are actually installed
sub list_dbi_drivers
{
local @rv = ( { 'name' => 'MySQL',
		'driver' => 'mysql',
		'dbparam' => 'database' },
	      { 'name' => 'PostgreSQL',
		'driver' => 'Pg',
		'dbparam' => 'dbname' },
	    );
@rv = grep { eval "use DBD::$_->{'driver'}"; !$@ } @rv;
return @rv;
}

# list_servers()
# Returns a list of servers that a command can run on
sub list_servers
{
if (&foreign_installed("servers")) {
	&foreign_require("servers", "servers-lib.pl");
	@servers = grep { $_->{'user'} } &servers::list_servers();
	if (@servers) {
		return ( { 'id' => 0, 'desc' => $text{'edit_this'} }, @servers);
		}
	}
return ( { 'id' => 0, 'desc' => $text{'edit_this'} } );
}

# execute_custom_command(&command, environment, exports, string, print-output)
# Runs some command, and returns the bytes, output and timeout flag
sub execute_custom_command
{
local ($cmd, $env, $export, $str, $print) = @_;
&foreign_require("proc", "proc-lib.pl");

&clean_environment() if ($cmd->{'clear'});
local $got;
local $outtemp = &transname();
open(OUTTEMP, ">$outtemp");
local $fh = $print ? STDOUT : *OUTTEMP;
if ($cmd->{'su'}) {
	local $temp = &transname();
	&open_tempfile(TEMP, ">$temp");
	&print_tempfile(TEMP, "#!/bin/sh\n");
	&print_tempfile(TEMP, $env);
	&print_tempfile(TEMP, "export $export\n") if ($export);
	&print_tempfile(TEMP, "$str\n");
	&close_tempfile(TEMP);
	chmod(0755, $temp);
	$got = &foreign_call("proc", "safe_process_exec",
			     &command_as_user($user, 1, $temp), 0, 0,
			     $fh, undef, !$cmd->{'raw'}, 0,
			     $cmd->{'timeout'});
	unlink($temp);
	}
else {
	$got = &foreign_call("proc", "safe_process_exec", $str,
			     $user_info[2], undef, $fh, undef,
			     !$cmd->{'raw'}, 0, $cmd->{'timeout'});
	}
&reset_environment() if ($cmd->{'clear'});
close(OUTTEMP);
local $rv = &read_file_contents($outtemp);
unlink($outtemp);
return ($got, $rv, $proc::safe_process_exec_timeout ? 1 : 0);
}

1;
