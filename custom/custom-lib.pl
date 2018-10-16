# custom-lib.pl
# Functions for storing custom commands

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();

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
		$cmd{'format'} = $o[8] eq '-' ? undef : $o[8];
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
		chop($cmd{'beforeedit'} = <FILE>);
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
		chop($cmd{'order'} = <FILE>);
		}
	if (%cmd) {
		# Read common stuff
		while(<FILE>) {
			s/\r|\n//g;
			local @a = split(/:/, $_, 5);
			local ($quote, $must) = split(/,/, $a[3]);
			push(@{$cmd{'args'}}, { 'name' => $a[0],
						'type' => $a[1],
						'opts' => $a[2],
						'quote' => int($quote),
						'must' => int($must),
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

# sort_commands(&command, ...)
# Sorts a list of custom commands by the user-defined order
sub sort_commands
{
local @cust = @_;
if ($config{'sort'}) {
	@cust = sort { lc($a->{$config{'sort'}}) cmp
		       lc($b->{$config{'sort'}}) } @cust;
	}
else {
	@cust = sort { local $o = $b->{'order'} <=> $a->{'order'};
		       $o ? $o : $a->{'id'} <=> $b->{'id'} } @cust;
	}
return @cust;
}

# get_command(id)
# Returns the command with some ID
sub get_command
{
local ($id, $idx) = @_;
local @cmds = &list_commands();
local $cmd;
if ($id) {
	($cmd) = grep { $_->{'id'} eq $id } &list_commands();
	}
else {
	$cmd = $cmds[$idx];
	}
return $cmd;
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
	&print_tempfile(FILE, $c->{'beforeedit'},"\n");
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
	&print_tempfile(FILE, $c->{'order'},"\n");
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
		   int($c->{'clear'})," ",($c->{'format'} || "-"),"\n");
	}


# Save parameters
foreach $a (@{$c->{'args'}}) {
	&print_tempfile(FILE, $a->{'name'},":",$a->{'type'},":",
	   $a->{'opts'},":",int($a->{'quote'}),",",int($a->{'must'}),":",
	   $a->{'desc'},"\n");
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
# Read the file containing possible menu options for a command
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
	next if (/^#/);
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

local $ptable = &ui_columns_start([
	$text{'edit_name'}, $text{'edit_desc'}, $text{'edit_type'},
	$noquote ? ( ) : ( $text{'edit_quote'} ),
	$text{'edit_must'},
	], 100, 0, undef, undef);
local @a = (@{$cmd->{'args'}}, { });
for(my $i=0; $i<@a; $i++) {
	local @cols;
	push(@cols, &ui_textbox("name_$i", $a[$i]->{'name'}, 10));
	push(@cols, &ui_textbox("desc_$i", $a[$i]->{'desc'}, 40));
	local @opts;
	for(my $j=0; $text{"edit_type$j"}; $j++) {
		next if ($editor &&
			 ($j == 7 || $j == 8 || $j == 10 || $j == 11));
		push(@opts, [ $j, $text{"edit_type$j"} ]);
		}
	push(@cols, &ui_select("type_$i", $a[$i]->{'type'}, \@opts)." ".
		    &ui_textbox("opts_$i", $a[$i]->{'opts'}, 40));
	if (!$noquote) {
		push(@cols, &ui_yesno_radio("quote_$i",
					    int($a[$i]->{'quote'})));
		}
	push(@cols, &ui_yesno_radio("must_$i",
                                    int($a[$i]->{'must'})));
	$ptable .= &ui_columns_row(\@cols);
	}

$ptable .= &ui_columns_end();
print $ptable;
}

# parse_params_inputs(&command)
sub parse_params_inputs
{
local ($cmd) = @_;
$cmd->{'args'} = [ ];
my ($i, $name);
for($i=0; defined($name = $in{"name_$i"}); $i++) {
	if ($name) {
		if ($in{"type_$i"} == 9 || $in{"type_$i"} == 12 ||
		    $in{"type_$i"} == 13 || $in{"type_$i"} == 14) {
			$in{"opts_$i"} =~ /\|$/ || -r $in{"opts_$i"} ||
				&error(&text('save_eopts', $i+1));
			}
		$in{"opts_$i"} =~ /:/ && &error(&text('save_eopts2', $i+1));
		push(@{$cmd->{'args'}}, { 'name' => $name,
					  'desc' => $in{"desc_$i"},
					  'type' => $in{"type_$i"},
					  'quote' => int($in{"quote_$i"}),
					  'must' => int($in{"must_$i"}),
					  'opts' => $in{"opts_$i"} });
		}
	}
}

# set_parameter_envs(&command, command-str, &uinfo, [set-in], [skip-menu-check])
# Sets $ENV variables based on parameter inputs, and returns the list of
# environment variable commands, the export commands, the command string,
# and the command string to display.
sub set_parameter_envs
{
local ($cmd, $str, $uinfo, $setin, $skipfound) = @_;
$setin ||= \%in;
local $displaystr = $str;
local ($env, $export, @vals);
foreach my $a (@{$cmd->{'args'}}) {
	my $n = $a->{'name'};
	my $rv;
	if ($a->{'type'} == 0 || $a->{'type'} == 5 ||
	    $a->{'type'} == 6 || $a->{'type'} == 8) {
		$rv = $setin->{$n};
		}
	elsif ($a->{'type'} == 11) {
		$rv = $setin->{$n};
		$rv =~ s/\r//g;
		$rv =~ s/\n/ /g;
		}
	elsif ($a->{'type'} == 1 || $a->{'type'} == 2) {
		(@u = getpwnam($setin->{$n})) || &error($text{'run_euser'});
		$rv = $a->{'type'} == 1 ? $setin->{$n} : $u[2];
		}
	elsif ($a->{'type'} == 3 || $a->{'type'} == 4) {
		(@g = getgrnam($setin->{$n})) || &error($text{'run_egroup'});
		$rv = $a->{'type'} == 3 ? $setin->{$n} : $g[2];
		}
	elsif ($a->{'type'} == 7) {
		$rv = $setin->{$n} ? $a->{'opts'} : "";
		}
	elsif ($a->{'type'} == 9) {
		local $found;
		foreach my $l (&read_opts_file($a->{'opts'})) {
			$found++ if ($l->[0] eq $setin->{$n});
			}
		$found || $skipfound || &error($text{'run_eopt'});
		$rv = $setin->{$n};
		}
	elsif ($a->{'type'} == 10) {
		if ($setin->{$n}) {
			if ($setin->{$n."_filename"} =~ /([^\/\\]+$)/ && $1) {
				$rv = &transname("$1");
				}
			else {
				$rv = &transname();
				}
			&open_tempfile(TEMP, ">$rv");
			&print_tempfile(TEMP, $setin->{$n});
			&close_tempfile(TEMP);
			chown($uinfo->[2], $uinfo->[3], $rv);
			push(@unlink, $rv);
			}
		else {
			$a->{'must'} && &error($text{'run_eupload'});
			$rv = undef;
			}
		}
	elsif ($a->{'type'} == 12 || $a->{'type'} == 13 || $a->{'type'} == 14) {
		local @vals;
		if ($a->{'type'} == 14) {
			@vals = split(/\r?\n/, $setin->{$n});
			}
		else {
			@vals = split(/\0/, $setin->{$n});
			}
		local @opts = &read_opts_file($a->{'opts'});
		foreach my $v (@vals) {
			local $found;
			foreach my $l (@opts) {
				$found++ if ($l->[0] eq $v);
				}
			$found || $skipfound || &error($text{'run_eopt'});
			}
		$rv = join(" ", @vals);
		}
	elsif ($a->{'type'} == 15) {
		$rv = $setin->{$n."_year"}."-".
		      $setin->{$n."_month"}."-".
		      $setin->{$n."_day"};
		}
	elsif ($a->{'type'} == 16) {
		$rv = $setin->{$n} ? 1 : 0;
		}
	if ($rv eq '' && $a->{'must'} && $a->{'type'} != 7) {
		&error(&text('run_emust', $a->{'desc'}));
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
	$got = &proc::safe_process_exec(
			     &command_as_user($user, 1, $temp), 0, 0,
			     $fh, undef, !$cmd->{'raw'} && !$cmd->{'format'}, 0,
			     $cmd->{'timeout'});
	unlink($temp);
	}
else {
	$got = &proc::safe_process_exec(
			     $str, $user_info[2], undef, $fh, undef,
			     !$cmd->{'raw'} && !$cmd->{'format'}, 0,
			     $cmd->{'timeout'});
	}
local $ex = $?;
&reset_environment() if ($cmd->{'clear'});
close(OUTTEMP);
local $rv = &read_file_contents($outtemp);
unlink($outtemp);
return ($got, $rv, $proc::safe_process_exec_timeout ? 1 : 0, $ex);
}

# show_parameter_input(&arg, formno)
# Returns HTML for a parameter input
sub show_parameter_input
{
local ($a, $form) = @_;
local $n = $a->{'name'};
local $v = $a->{'opts'};
if ($a->{'type'} != 9 && $a->{'type'} != 12 &&
    $a->{'type'} != 13 && $a->{'type'} != 14) {
	if ($v =~ /^"(.*)"$/ || $v =~ /^'(.*)'$/) {
		# Quoted default
		$v = $1;
		}
	elsif ($v =~ /^(.*)\s*\|$/ && $config{'params_cmd'}) {
		# Command to run
		$v = &backquote_command("$1 2>/dev/null </dev/null");
		if ($a->{'type'} != 11) {
			$v =~ s/[\r\n]+$//;
			}
		}
	elsif ($v =~ /^\// && $config{'params_file'}) {
		# File to read
		$v = &read_file_contents($v);
		if ($a->{'type'} != 11) {
			$v =~ s/[\r\n]+$//;
			}
		}
	}
if ($a->{'type'} == 0) {
	return &ui_textbox($n, $v, 30);
	}
elsif ($a->{'type'} == 1 || $a->{'type'} == 2) {
	return &ui_user_textbox($n, $v, $form);
	}
elsif ($a->{'type'} == 3 || $a->{'type'} == 4) {
	return &ui_group_textbox($n, $v, $form);
	}
elsif ($a->{'type'} == 5 || $a->{'type'} == 6) {
	return &ui_textbox($n, $v, 30)." ".
	       &file_chooser_button($n, $a->{'type'}-5, $form);
	}
elsif ($a->{'type'} == 7) {
	return &ui_yesno_radio($n, $v =~ /true|yes|1/ ? 1 : 0);
	}
elsif ($a->{'type'} == 8) {
	return &ui_password($n, $v, 30);
	}
elsif ($a->{'type'} == 9) {
	return &ui_select($n, undef, [ &read_opts_file($a->{'opts'}) ]);
	}
elsif ($a->{'type'} == 10) {
	return &ui_upload($n, 30);
	}
elsif ($a->{'type'} == 11) {
	return &ui_textarea($n, $v, 4, 30);
	}
elsif ($a->{'type'} == 12) {
	return &ui_select($n, undef, [ &read_opts_file($a->{'opts'}) ],
			  5, 1);
	}
elsif ($a->{'type'} == 13) {
	my @opts = &read_opts_file($a->{'opts'});
	return &ui_select($n, undef, \@opts, scalar(@opts), 1);
	}
elsif ($a->{'type'} == 14) {
	my @opts = &read_opts_file($a->{'opts'});
	return &ui_multi_select($n, [ ], \@opts, 5);
	}
elsif ($a->{'type'} == 15) {
	my ($year, $month, $day) = split(/\-/, $v);
	return &ui_date_input($day, $month, $year,
			      $n."_day", $n."_month", $n."_year")."&nbsp;".
	       &date_chooser_button($n."_day", $n."_month", $n."_year");
	}
elsif ($a->{'type'} == 16) {
	return &ui_submit($v || $a->{'name'}, $a->{'name'}); 
	}
else {
	return "Unknown parameter type $a->{'type'}";
	}
}


1;
