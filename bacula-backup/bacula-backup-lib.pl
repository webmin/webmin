# Common functions for the bacula config file
# XXX schedule chooser on IE

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
use Time::Local;
if (&foreign_check("node-groups")) {
	&foreign_require("node-groups", "node-groups-lib.pl");
	}

$cmd_prefix = &has_command("bareos-dir") ? "bareos" : "bacula";
$dir_conf_file = "$config{'bacula_dir'}/$cmd_prefix-dir.conf";
$fd_conf_file = "$config{'bacula_dir'}/$cmd_prefix-fd.conf";
$sd_conf_file = "$config{'bacula_dir'}/$cmd_prefix-sd.conf";
$bconsole_conf_file = "$config{'bacula_dir'}/bconsole.conf";
$console_conf_file = "$config{'bacula_dir'}/console.conf";
$console_cmd = -r "$config{'bacula_dir'}/bconsole" ?
		"$config{'bacula_dir'}/bconsole" :
	       -r "$config{'bacula_dir'}/console" ?
		"$config{'bacula_dir'}/console" :
	       &has_command("bconsole");
$bacula_cmd = -r "$config{'bacula_dir'}/bacula" ?
		"$config{'bacula_dir'}/bacula" :
	      &has_command("bacula");

@backup_levels = ( "Full", "Incremental", "Differential",
	   "InitCatalog", "Catalog", "VolumeToCatalog", "DiskToCatalog" );
@pool_types = ( "Backup",
		"*Archive", "*Cloned", "*Migration", "*Copy", "*Save" );

$cron_cmd = "$module_config_directory/sync.pl";

# connect_to_database()
# Connects to the Bacula database, and returns the DBI handle
sub connect_to_database
{
local $drh;
local $driver = $config{'driver'} || "mysql";
eval <<EOF;
use DBI;
\$drh = DBI->install_driver(\$driver);
EOF
if ($@) {
        die &text('connect_emysql', "<tt>$driver</tt>");
        }
local $dbistr = &make_dbistr($config{'driver'}, $config{'db'}, $config{'host'});
local $dbh = $drh->connect($dbistr,
                           $config{'user'}, $config{'pass'}, { });
$dbh || die &text('connect_elogin', "<tt>$config{'db'}</tt>",$drh->errstr)."\n";
local $testcmd = $dbh->prepare("select count(*) from job");
if (!$testcmd) {
	die &text('connect_equery', "<tt>$config{'db'}</tt>")."\n".
	    ($config{'driver'} eq "SQLite" ? $text{'connect_equery2'} : "");
	}
$testcmd->finish();
return $dbh;
}

# read_config_file(file)
# Parses a bacula config file
sub read_config_file
{
local ($file) = @_;
if (!defined($config_file_cache{$file})) {
	local @rv = ( );
	local $parent = { 'members' => \@rv };
	local $lnum = 0;
	open(CONF, $_[0]) || return undef;
	local @lines = <CONF>;
	close(CONF);
	for(my $i=0; $i<@lines; $i++) {
		$_ = $lines[$i];
		s/\r|\n//g;
		s/#.*$//;
		if (/^\s*\@(.*\S)/) {
			# An include file reference .. parse it
			local $incfile = $1;
			# A pipe command                                                                                                          
                        if ($incfile =~ /^\|"(.*)"$/) {
                            local $command = $1;
                            local $incfiles = `$command`;
                            foreach (split(/\s/,$incfiles)) {
                                local $inc = &read_config_file(substr($_,1));
                                push(@{$parent->{'members'}}, @$inc);
                            }
                        }
			if ($incfile !~ /^\//) {
				$incfile = "$config{'bacula_dir'}/$incfile";
				}
			if (-d $incfile) {
				# Read a whole directory of files
				opendir(INCDIR, $incfile);
				foreach my $f (readdir(INCDIR)) {
					next if ($f eq "." || $f eq "..");
					local $inc = &read_config_file(
						"$incfile/$f");
					push(@{$parent->{'members'}}, @$inc);
					}
				closedir(INCDIR);
				}
			else {
				# Read just one file
				local $inc = &read_config_file($incfile);
				push(@{$parent->{'members'}}, @$inc);
				}
			}
		elsif (/^\s*}\s*$/) {
			# End of a section
			$parent->{'eline'} = $lnum;
			$parent = $parent->{'parent'};
			$parent ||
			    die "Too many section ends at line ".($lnum+1);
			}
		elsif (/^\s*(\S+)\s*{\s*(\S[^=]*\S)\s*=\s*"(.*)"(.*)$/ ||
		       /^\s*(\S+)\s*{\s*(\S[^=]*\S)\s*=\s*([^\{]*\S)(.*)$/) {
			# Start of a section, with a name=value record on
			# the same line!
			local $dir = { 'name' => $1,
				       'parent' => $parent,
				       'line' => $lnum,
				       'eline' => $lnum,
				       'file' => $file,
				       'type' => 1,
				       'members' => [ ] };
			push(@{$parent->{'members'}}, $dir);
			$parent = $dir;
			local $dir = { 'name' => $2,
				       'value' => $3,
				       'line' => $lnum,
				       'eline' => $lnum,
				       'file' => $file,
				       'type' => 0,
				       'parent' => $parent };
			push(@{$parent->{'members'}}, $dir);
			}
		elsif (/^\s*(\S[^=]*\S)\s*=\s*"(.*)"(.*)$/ ||
		    /^\s*(\S[^=]*\S)\s*=\s*([^\{]*\S)(.*)$/) {
			# A name=value record
			local $rest = $3;
			local $dir = { 'name' => $1,
				       'value' => $2,
				       'line' => $lnum,
				       'eline' => $lnum,
				       'file' => $file,
				       'type' => 0,
				       'parent' => $parent };
			push(@{$parent->{'members'}}, $dir);

			if ($rest =~ /\s*{\s*$/) {
				# Also start of a section!
				$dir->{'type'} = 2;
				$dir->{'members'} = [ ];
				$parent = $dir;
				}
			}
		elsif (/^\s*(\S[^=]*\S)\s*=\s*$/) {
			# A name = with no value
			local $rest = $3;
			local $dir = { 'name' => $1,
				       'value' => undef,
				       'line' => $lnum,
				       'eline' => $lnum,
				       'file' => $file,
				       'type' => 0,
				       'parent' => $parent };
			push(@{$parent->{'members'}}, $dir);
			}
		elsif (/^\s*(\S+)\s*{\s*$/) {
			# Start of a section
			local $dir = { 'name' => $1,
				       'parent' => $parent,
				       'line' => $lnum,
				       'eline' => $lnum,
				       'file' => $file,
				       'type' => 1,
				       'members' => [ ] };
			push(@{$parent->{'members'}}, $dir);
			$parent = $dir;
			}
		elsif (/^\s*(\S+)\s*$/) {
			# Just a word by itself .. perhaps start of a section,
			# if there is a { on the next line.
			local $name = $1;
			local $nextline = $lines[++$i];
			if ($nextline =~ /^\s*\{\s*$/) {
				local $dir = { 'name' => $name,
					       'parent' => $parent,
					       'line' => $lnum,
					       'eline' => $lnum,
					       'file' => $file,
					       'type' => 1,
					       'members' => [ ] };
				push(@{$parent->{'members'}}, $dir);
				$parent = $dir;
				$lnum++;
				}
			}
		$lnum++;
		}
	$config_file_cache{$file} = \@rv;
	}
return $config_file_cache{$file};
}

# read_config_file_parent(file)
sub read_config_file_parent
{
local ($file) = @_;
if (!$config_file_parent_cache{$file}) {
	local $conf = &read_config_file($file);
	return undef if (!$conf);
	local $lref = &read_file_lines($file);
	$config_file_parent_cache{$file} =
	       { 'members' => $conf,
		 'type' => 2,
		 'file' => $file,
		 'line' => 0,
		 'eline' => scalar(@$lref) };
	}
return $config_file_parent_cache{$file};
}

# find(name, &conf)
sub find
{
local ($name, $conf) = @_;
local @rv = grep { &normalize_name($_->{'name'}) eq &normalize_name($name) }
		 @$conf;
return wantarray ? @rv : $rv[0];
}

sub find_value
{
local ($name, $conf) = @_;
local @rv = map { $_->{'value'} } &find(@_);
return wantarray ? @rv : $rv[0];
}

# normalize_name(name)
# Convert a Bacula config name like "Run Before" to "runbefore" for comparison
# purposes
sub normalize_name
{
local ($name) = @_;
$name = lc($name);
$name =~ s/\s+//g;
return $name;
}

sub find_by
{
local ($field, $value, $conf) = @_;
foreach my $f (@$conf) {
	my $name = &find_value($field, $f->{'members'});
	return $f if ($name eq $value);
	}
return undef;
}

sub get_director_config
{
return &read_config_file($dir_conf_file);
}

sub get_director_config_parent
{
return &read_config_file_parent($dir_conf_file);
}

sub get_storage_config
{
return &read_config_file($sd_conf_file);
}

sub get_storage_config_parent
{
return &read_config_file_parent($sd_conf_file);
}

sub get_file_config
{
return &read_config_file($fd_conf_file);
}

sub get_file_config_parent
{
return &read_config_file_parent($fd_conf_file);
}

sub get_bconsole_config
{
return &read_config_file($bconsole_conf_file);
}

sub get_bconsole_config_parent
{
return &read_config_file_parent($bconsole_conf_file);
}

# save_directive(&conf, &parent, name|&old, &new, indent)
# Updates a section or value in the Bacula config file
sub save_directive
{
local ($conf, $parent, $name, $new, $indent) = @_;
local $old;
if (ref($name)) {
	$old = $name;
	$name = $old->{'name'};
	}
else {
	$old = &find($name, $parent->{'members'});
	}
local $lref = $old && $old->{'file'} ? &read_file_lines($old->{'file'}) :
	      $parent->{'file'} ? &read_file_lines($parent->{'file'}) : undef;
if (defined($new) && !ref($new)) {
	$new = { 'name' => $name,
		 'value' => $new };
	}

local @lines = $new ? &directive_lines($new, $indent) : ( );
local $len = $old ? $old->{'eline'} - $old->{'line'} + 1 : undef;
if ($old && $new) {
	# Update this object
	if ($lref) {
		splice(@$lref, $old->{'line'}, $len, @lines);
		&renumber($conf, $old->{'line'}, scalar(@lines)-$len,
			  $old->{'file'});
		}
	$old->{'value'} = $new->{'value'};
	$old->{'members'} = $new->{'members'};
	$old->{'type'} = $new->{'type'};
	$old->{'eline'} = $old->{'line'} + scalar(@lines) - 1;
	}
elsif (!$old && $new) {
	# Add to the parent
	$new->{'line'} = $parent->{'eline'};
	$new->{'eline'} = $new->{'line'} + scalar(@lines) - 1;
	$new->{'file'} = $parent->{'file'};
	if ($lref) {
		splice(@$lref, $parent->{'eline'}, 0, @lines);
		&renumber($conf, $new->{'line'}-1, scalar(@lines),
			  $parent->{'file'});
		}
	push(@{$parent->{'members'}}, $new);
	}
elsif ($old && !$new) {
	# Delete from the parent
	if ($lref) {
		splice(@$lref, $old->{'line'}, $len);
		&renumber($conf, $old->{'line'}, -$len, $old->{'file'});
		}
	@{$parent->{'members'}} = grep { $_ ne $old } @{$parent->{'members'}};
	}
}

# save_directives(&conf, &parent, name, &newvalues, indent)
# Updates multiple directives in a section
sub save_directives
{
local ($conf, $parent, $name, $news, $indent) = @_;
local @news = map { ref($_) ? $_ : { 'name' => $name, 'value' => $_ } } @$news;
local @olds = &find($name, $parent->{'members'});
for(my $i=0; $i<@news || $i<@olds; $i++) {
	&save_directive($conf, $parent, $olds[$i], $news[$i], $indent);
	}
}

# renumber(&conf, start, offset, file)
sub renumber
{
local ($conf, $line, $offset, $file) = @_;
foreach my $c (@$conf) {
	$c->{'line'} += $offset if ($c->{'line'} > $line &&
				    $c->{'file'} eq $file);
	$c->{'eline'} += $offset if ($c->{'eline'} > $line &&
				     $c->{'file'} eq $file);
	if ($c->{'type'}) {
		&renumber($c->{'members'}, $line, $offset, $file);
		}
	}
local $parent = $config_file_parent_cache{$file};
if ($conf eq $parent->{'members'}) {
	# Update parent lines too
	$parent->{'line'} += $offset if ($parent->{'line'} > $line);
	$parent->{'eline'} += $offset if ($parent->{'eline'} > $line);
	}
}

# directive_lines(&object, indent)
# Returns the text lines of a Bacula directive
sub directive_lines
{
local ($dir, $indent) = @_;
local $istr = "  " x $indent;
local @rv;
if ($dir->{'type'}) {
	# A section
	push(@rv, $istr.$dir->{'name'}.
		  ($dir->{'value'} ? " $dir->{'value'}" : "")." {");
	foreach my $m (@{$dir->{'members'}}) {
		push(@rv, &directive_lines($m, $indent+1));
		}
	push(@rv, $istr."}");
	}
else {
	# A single line
	local $qstr = $dir->{'value'} =~ /^\S+$/ ||
		       $dir->{'value'} =~ /^\d+\s+(secs|seconds|mins|minutes|hours|days|weeks|months|years)$/i ||
		       $dir->{'name'} eq 'Run' ? $dir->{'value'} :
		      $dir->{'value'} =~ /"/ ? "'$dir->{'value'}'" :
					       "\"$dir->{'value'}\"";
	push(@rv, $istr.$dir->{'name'}." = ".$qstr);
	}
return @rv;
}

# bacula_file_button(filesfield, [jobfield], [volume])
# Pops up a window for selecting multiple files, using a tree-like view
sub bacula_file_button
{
return "<input type=button onClick='ifield = form.$_[0]; jfield = form.$_[1]; chooser = window.open(\"treechooser.cgi?volume=".&urlize($_[2])."&files=\"+escape(ifield.value)+\"&job=\"+escape(jfield.value), \"chooser\", \"toolbar=no,menubar=no,scrollbar=no,width=500,height=400\"); chooser.ifield = ifield; window.ifield = ifield' value=\"...\">\n";
}

sub tape_select
{
local $t;
print "<select name=tape>\n";
foreach $t (split(/\s+/, $config{'tape_device'})) {
	print "<option>",&text('index_tapedev', $t),"</option>\n";
	}
print "<option value=''>$text{'index_other'}</option>\n";
print "</select>\n";
print "<input name=other size=40> ",&file_chooser_button("other", 1),"\n";
}

# job_select(&dbh, [volume])
# XXX needs value input?
# XXX needs flag for use of 'any' field?
sub job_select
{
local $cmd;
if ($_[1]) {
	$cmd = $_[0]->prepare("select Job.JobId,Job.Name,Job.SchedTime ".
			      "from Job,JobMedia,Media ".
			      "where Job.JobId = JobMedia.JobId ".
			      "and Media.MediaId = JobMedia.MediaId ".
			      "and Media.VolumeName = '$_[1]'") ||
		&error("prepare failed : ",$dbh->errstr);
	}
else {
	$cmd = $_[0]->prepare("select JobId,Name,SchedTime from Job") ||
		&error("prepare failed : ",$dbh->errstr);
	}
$cmd->execute();
print "<select name=job>\n";
print "<option value=''>$text{'job_any'}</option>\n";
while(my ($id, $name, $when) = $cmd->fetchrow()) {
	$when =~ s/ .*$//;
	print "<option value=$id>$name ($id) ($when)</option>\n";
	}
print "</select>\n";
}

# client_select(&dbh)
sub client_select
{
local $cmd = $_[0]->prepare("select ClientId,Name from Client order by ClientId asc");
$cmd->execute();
print "<select name=client>\n";
while(my ($id, $name) = $cmd->fetchrow()) {
	print "<option value=$name>$name ($id)</option>\n";
	}
print "</select>\n";
}

sub unix_to_dos
{
local $rv = $_[0];
$rv =~ s/^\/([a-zA-Z]):/$1:/;
return $rv;
}

sub dos_to_unix
{
local $rv = $_[0];
$rv =~ s/^([a-zA-Z]):/\/$1:/;
return $rv;
}

# check_bacula()
# Returns an error message if bacula is not installed, or undef if OK
sub check_bacula
{
if (!-d $config{'bacula_dir'}) {
	return &text('check_edir', "<tt>$config{'bacula_dir'}</tt>");
	}
local $got = 0;
if (-r $dir_conf_file) {
	#if (!-x $bacula_cmd) {
	#	return &text('check_ebacula', "<tt>$bacula_cmd</tt>");
	#	}
	if (!-x $console_cmd) {
		return &text('check_econsole', "<tt>$console_cmd</tt>");
		}
	$got++;
	}
elsif (-r $fd_conf_file) {
	$got++;
	}
elsif (-r $sd_conf_file) {
	$got++;
	}
return &text('check_econfigs', "<tt>$config{'bacula_dir'}</tt>") if (!$got);
return undef;
}

# Returns 1 if this system is a Bacula director
sub has_bacula_dir
{
return -r $dir_conf_file;
}

# Returns 1 if this system is a Bacula file daemon
sub has_bacula_fd
{
return -r $fd_conf_file;
}

# Returns 1 if this system is a Bacula storage daemon
sub has_bacula_sd
{
return -r $sd_conf_file;
}

# Names of the Bacula programs
@bacula_processes = ( &has_bacula_dir() ? ( $cmd_prefix."-dir" ) : ( ),
		      &has_bacula_sd() ? ( $cmd_prefix."-sd" ) : ( ),
		      &has_bacula_fd() ? ( $cmd_prefix."-fd" ) : ( ),
		    );
if ($gconfig{'os_type'} eq 'windows') {
	# On Windows, the bootup action is just called Bacula (for the FD)
	@bacula_inits = ( "Bacula" );
	}
else {
 	# On Unix, each daemon has an action
	@bacula_inits = @bacula_processes;
	foreach my $i (@bacula_inits) {
		if ($i eq "bacula-dir" && !-r "/etc/init.d/$i" &&
		    -r "/etc/init.d/bacula-director") {
			# Different location on Ubuntu / Debian
			$i = "bacula-director";
			}
		}
	}

# is_bacula_running(process)
# Returns 1 if the specified Bacula process is running, 0 of not
sub is_bacula_running
{
local ($proc) = @_;
if (&has_command($bacula_cmd)) {
	# Get status from bacula status command
	$bacula_status_cache ||=
		&backquote_command("$bacula_cmd status 2>&1 </dev/null");
	if ($bacula_status_cache =~ /\Q$proc\E\s+\(pid\s+([0-9 ]+)\)\s+is\s+running/i ||
	    $bacula_status_cache =~ /\Q$proc\E\s+is\s+running/i) {
		return 1;
		}
	}
# Look for running process
local @pids = &find_byname($proc);
return @pids ? 1 : 0;
}

# start_bacula()
# Attempts to start the Bacula processes, return undef on success or an
# error message on failure
sub start_bacula
{
undef($bacula_status_cache);
if (&has_command($bacula_cmd) && !$config{'init_start'}) {
	local $out = &backquote_logged("$bacula_cmd start 2>&1 </dev/null");
	return $? || $out =~ /failed|error/i ? "<pre>$out</pre>" : undef;
	}
else {
	return &run_all_inits("start");
	}
}

# stop_bacula()
# Attempts to stop the Bacula processes, return undef on success or an
# error message on failure
sub stop_bacula
{
undef($bacula_status_cache);
if (&has_command($bacula_cmd) && !$config{'init_start'}) {
	local $out = &backquote_logged("$bacula_cmd stop 2>&1 </dev/null");
	return $? || $out =~ /failed|error/i ? "<pre>$out</pre>" : undef;
	}
else {
	return &run_all_inits("stop");
	}
}

# restart_bacula()
# Attempts to re-start the Bacula processes, return undef on success or an
# error message on failure
sub restart_bacula
{
undef($bacula_status_cache);
if (&has_command($bacula_cmd) && !$config{'init_start'}) {
	local $out = &backquote_logged("$bacula_cmd restart 2>&1 </dev/null");
	return $? || $out =~ /failed|error/i ? "<pre>$out</pre>" : undef;
	}
else {
	return &run_all_inits("restart");
	}
}

# run_all_inits(action)
# Runs all the Bacula init script with some action
sub run_all_inits
{
local ($action) = @_;
&foreign_require("init", "init-lib.pl");
foreach my $i (@bacula_inits) {
	local $st = &init::action_status($i);
	return &text('start_einit', "<tt>$i</tt>") if (!$st);
	}
foreach my $i (@bacula_inits) {
	local $func = $action eq "start" ? \&init::start_action :
		      $action eq "stop" ? \&init::stop_action :
		      $action eq "restart" ? \&init::restart_action :
					     undef;
	$func || return "Unknown init action $action";
	local ($ok, $err) = &$func($i);
	if (!$ok) {
		return &text('start_erun', "<tt>$i</tt>", "<pre>$err</pre>");
		}
	}
return undef;
}

# apply_configuration()
# Tells Bacula to re-read it's config files
sub apply_configuration
{
if (&has_bacula_dir()) {
	# Call console reload
	local $h = &open_console();
	local $out = &console_cmd($h, "reload");
	&close_console($h);
	return defined($out) ? undef : $text{'apply_failed'}."<pre>$out</pre>";
	}
else {
	# Need to do a restart
	return &restart_bacula();
	}
}

# auto_apply_configuration()
# Apply the configuration if automatic apply is enabled
sub auto_apply_configuration
{
if ($config{'apply'} && &is_bacula_running($bacula_processes[0])) {
	local $err = &apply_configuration();
	&error(&text('apply_problem', $err)) if ($err);
	}
}

# show_period_input(name, value)
# Returns HTML for selection a retention period
sub show_period_input
{
local ($name, $value) = @_;
local ($t, $u) = split(/\s+/, $value);
$u ||= "days";
$u .= "s" if ($u !~ /s$/);
return &ui_textbox($name."_t", $t, 5)." ".
       &ui_select($name."_u", $u,
	  [ [ "seconds" ], [ "minutes" ], [ "hours" ], [ "days" ],
	    [ "weeks" ], [ "months" ], [ "years" ] ], 1, 0, 1);
}

# parse_period_input(name)
sub parse_period_input
{
local ($name) = @_;
$in{$name."_t"} =~ /^\d+$/ || return undef;
return $in{$name."_t"}." ".$in{$name."_u"};
}

# find_dependency(field, value, &types, &conf)
# Checks if any of the given object types have the specified field, and returns
# the name of the dependent object
sub find_dependency
{
local ($field, $value, $types, $conf) = @_;
foreach my $name (@$types) {
	local @children = &find($name, $conf);
	local $child = &find_by($field, $value, \@children);
	if ($child) {
		local $cname = &find_value("Name", $child->{'members'});
		return $cname;
		}
	}
return undef;
}

# open_console()
# Starts the Bacula console process, and returns a handle object for it
sub open_console
{
##&foreign_require("proc", "proc-lib.pl");
#$ENV{'TERM'} = "dumb";
#local ($fh, $fpid) = &proc::pty_process_exec($console_cmd);
#&wait_for($fh, '\\*');		# skip first prompt
#return { 'fh' => $fh,
#	 'fpid' => $fpid };

pipe(INr, INw);
pipe(OUTr, OUTw);
local $pid;
if (!($pid = fork())) {
        untie(*STDIN);
        untie(*STDOUT);
        untie(*STDERR);
        close(STDIN);
        close(STDOUT);
        close(STDERR);
        open(STDIN, "<&INr");
        open(STDOUT, ">&OUTw");
        open(STDERR, ">&OUTw");
        $| = 1;
        close(INw);
	close(OUTr);
        chdir($config{'bacula_dir'});
        exec($console_cmd);
        print STDERR "exec failed : $!\n";
        exit(1);
        }
close(INr);
close(OUTw);
local $infh = \*INw;
local $outfh = \*OUTr;
local $old = select($infh); $| = 1;
select($outfh); $| = 1; select($old);
return { 'infh' => $infh,
	 'outfh' => $outfh,
	 'fpid' => $pid };
}

# console_cmd(&handle, command)
# Runs one Bacula command, and returns the output
sub console_cmd
{
local ($h, $cmd) = @_;
&sysprint($h->{'infh'}, $cmd."\n");
if ($cmd ne "quit") {
	&sysprint($h->{'infh'}, "time\n");
	}
local $out;
while(1) {
        local $rv = &wait_for($h->{'outfh'},
                        '^(\S+\s+)?(\d+\-\S+\-\d+ \d+:\d+:\d+)\n',
                        'Unable to connect to Director',
                        '.*\n');
        return undef if ($rv == 1 || $rv < 0);
        $out .= $wait_for_input;
        last if ($rv == 0);
        }
$out =~ s/time\n(\S+\s+)?(\d+\-\S+\-\d+ \d+:\d+:\d+)\n//;
$out =~ s/^\Q$cmd\E\n//;
return $out;
}

# close_console(&handle)
sub close_console
{
local ($h) = @_;
&console_cmd($h, "quit");
close($h->{'infh'});
close($h->{'outfh'});
kill('TERM', $h->{'fpid'});
waitpid($h->{'pid'}, -1);
}

# get_bacula_version()
# Get the Bacula version, either from one of the command-line programs, or
# from the console
sub get_bacula_version
{
foreach my $p (@bacula_processes) {
	if (&has_command($p)) {
		local $out = `$p -\? 2>&1`;
		if ($out =~ /Version:\s+(\S+)/) {
			return $1;
			}
		}
	}
local $h = &open_console();
local $out = &console_cmd($h, "version");
&close_console($h);
if ($out =~ /Version:\s+(\S+)/) {
	&open_tempfile(CACHE, ">$module_config_directory/version");
	&print_tempfile(CACHE, $1,"\n");
	&close_tempfile(CACHE);
	return $1;
	}
return undef;
}

sub get_bacula_version_cached
{
open(CACHE, "$module_config_directory/version");
chop($version = <CACHE>);
close(CACHE);
return $version || &get_bacula_version();
}

# get_bacula_jobs()
# Returns a list of all jobs known to Bacula
sub get_bacula_jobs
{
local $h = &open_console();
local $jobs = &console_cmd($h, "show jobs");
&close_console($h);
local @rv;
local $job;
foreach my $l (split(/\r?\n/, $jobs)) {
	if ($l =~ /^Job:\s+name=([^=]*\S)\s/i ||
	    $l =~ /^\s*Name\s*=\s*"(.*)"/i) {
		$job = { 'name' => $1 };
		push(@rv, $job);
		}
	elsif (($l =~ /Client:\s+name=([^=]*\S)\s/i ||
		$l =~ /^\s*Client\s*=\s*"(.*)"/i) && $job) {
		$job->{'client'} = $1;
		}
	elsif (($l =~ /FileSet:\s+name=([^=]*\S)\s/i ||
	        $l =~ /^FileSet\s*=\s*"(.*)"/i) && $job) {
		$job->{'fileset'} = $1;
		}
	}
return @rv;
}

# get_bacula_clients()
# Returns a list of all clients known to Bacula
sub get_bacula_clients
{
local $h = &open_console();
local $clients = &console_cmd($h, "show clients");
&close_console($h);
local @rv;
local $client;
foreach my $l (split(/\r?\n/, $clients)) {
	if ($l =~ /^Client:\s+name=([^=]*\S)\s/i ||
	    $l =~ /^\s*Name\s*=\s*"(.*)"/i) {
		$client = { 'name' => $1 };
		if ($l =~ /address=(\S+)/i && $client) {
			$client->{'address'} = $1;
			}
		if ($l =~ /FDport=(\d+)/i && $client) {
			$client->{'port'} = $1;
			}
		push(@rv, $client);
		}
	elsif ($l =~ /^\s*Address\s*=\s*"(.*)"/i && $client) {
		$client->{'address'} = $1;
		}
	elsif ($l =~ /^\s*FDport\s*=\s*"(.*)"/i && $client) {
		$client->{'port'} = $1;
		}
	}
return @rv;
}

# get_bacula_storages()
# Returns a list of all storage daemons known to Bacula
sub get_bacula_storages
{
local $h = &open_console();
local $storages = &console_cmd($h, "show storages");
&close_console($h);
local @rv;
local $storage;
foreach my $l (split(/\r?\n/, $storages)) {
	if ($l =~ /^Storage:\s+name=([^=]*\S)\s/i ||
	    $l =~ /^\s*Name\s*=\s*"(.*)"/i) {
		$storage = { 'name' => $1 };
		if ($l =~ /address=(\S+)/i) {
			$storage->{'address'} = $1;
			}
		if ($l =~ /SDport=(\d+)/i) {
			$storage->{'port'} = $1;
			}
		push(@rv, $storage);
		}
	elsif ($l =~ /^\s*Address\s*=\s*"(.*)"/i && $storage) {
		$storage->{'address'} = $1;
		}
	elsif ($l =~ /^\s*SDport\s*=\s*"(.*)"/i && $storage) {
		$storage->{'port'} = $1;
		}
	}
return @rv;
}

# get_bacula_pools()
# Returns a list of all pools known to Bacula
sub get_bacula_pools
{
local $h = &open_console();
local $pools = &console_cmd($h, "show pools");
&close_console($h);
local @rv;
local $pool;
foreach my $l (split(/\r?\n/, $pools)) {
	if ($l =~ /^Pool:\s+name=([^=]*\S)\s/i ||
	    $l =~ /^\s*Name\s*=\s*"(.*)"/i) {
		$pool = { 'name' => $1 };
		if ($l =~ /PoolType=(\S+)/i) {
			$pool->{'type'} = $1;
			}
		push(@rv, $pool);
		}
	elsif ($l =~ /^\s*PoolType\s*=\s*"(.*)"/i && $pool) {
		$pool->{'type'} = $1;
		}
	}
return @rv;
}

# get_director_status()
# Returns three arrays, containing the status of scheduled, running and finished
# jobs respectively
sub get_director_status
{
local $h = &open_console();
local $status = &console_cmd($h, "status dir");
&close_console($h);
local $sect = 0;
local (@sched, @run, @done);
foreach my $l (split(/\r?\n/, $status)) {
	if ($l =~ /^Scheduled\s+Jobs/i) { $sect = 1; }
	elsif ($l =~ /^Running\s+Jobs/i) { $sect = 2; }
	elsif ($l =~ /^Terminated\s+Jobs/i) { $sect = 3; }

	if ($sect == 1 && $l =~ /^\s*(\S+)\s+(\S+)\s+(\d+)\s+(\S+\s+\S+(\s+\d+:\d+)?)\s+(\S+)\s+(\S+)?\s*$/) {
		# Scheduled job, like 
		# Full Backup 10 27-Jun-14 17:30 ykfdc1-BackupJob wkly_1736
		# copy jobs do not have any destination tape (=> ? on the latest field)
		# Full Backup 11 19-Aug-16 17:50 ykfdc1-Copyjob
		push(@sched, { 'level' => &full_level("$1"),
			       'type' => $2,
			       'pri' => $3,
			       'date' => $4,
			       'name' => $6,
			       'volume' => $7 });
		}
	elsif ($sect == 2 && $l =~ /^\s*(\d+)\s+(\S+)\s+(\S+)\s+([0-9,]+)\s+([0-9,]+\.[0-9,]+\s+\S+|\d+)\s+(\S+)\s+(.*)/) {
		# Running job, like
		# 6252 Back Full 0 0 File1-BackupJob is running
		push(@run, { 'id' => $1,
			     'type' => $2,
			     'level' => &full_level("$3"),
			     'files' => &remove_comma("$4"),
			     'bytes' => &remove_comma("$5"),
			     'name' => $6,
			     'status' => $7 });
		}
	elsif ($sect == 2 && $l =~ /^\s*(\d+)\s+(\S+)\s+(\S+)\.(\d+\-\d+\-\S+)\s+(.*)/) {
		# Running job
		push(@run, { 'id' => $1,
			     'level' => &full_level("$2"),
			     'name' => &job_name("$3"),
			     'status' => $5 });
		}
	elsif ($sect == 2 && $l =~ /^\s*(\d+)\s+(\S+)\.(\d+\-\d+\-\S+)\s+(.*)/) {
		# Running job
		push(@run, { 'id' => $1,
			     'level' => "Restore",
			     'name' => &job_name("$2"),
			     'status' => $4 });
		}
	elsif ($sect == 3 && $l =~ /^\s*(\d+)\s+(\S+)\s+([0-9,]+)\s+([0-9,]+\.[0-9,]+\s+\S+|\d+)\s+(\S+)\s+(\S+\s+\S+)\s+(\S+)\s*$/){
		# Terminated job
		push(@done, { 'id' => $1,
			      'level' => &full_level("$2"),
			      'files' => &remove_comma("$3"),
			      'bytes' => &remove_comma("$4"),
			      'status' => $5,
			      'date' => $6,
			      'name' => &job_name("$7") });
		}
	}
return (\@sched, \@run, \@done);
}

# get_client_status(client)
# Returns a status message, OK flag, running jobs and done jobs for some client
sub get_client_status
{
local ($client) = @_;
local $h = &open_console();
local $status = &console_cmd($h, "status client=$client");
&close_console($h);
local $msg;
if ($status =~ /Connecting\s+to\s+Client.*\n(\n?)(.*)\n/i) {
	$msg = $2;
	$msg =~ s/^\s*$client\s//;
	}
local $sect = 0;
local (@run, @done);
foreach my $l (split(/\r?\n/, $status)) {
	if ($l =~ /^Running\s+Jobs/i) { $sect = 2; }
	elsif ($l =~ /^Terminated\s+Jobs/i) { $sect = 3; }

	if ($sect == 2 && $l =~ /^\s*JobID\s+(\d+)\s+Job\s+(\S+)\.(\d+\-\d+\-\S+)\s+(.*)/i) {
		push(@run, { 'id' => $1,
			     'name' => &job_name("$2"),
			     'status' => $4 });
		}
	elsif ($sect == 2 && $l =~ /^\s*Backup\s+Job\s+started:\s+(\S+\s+\S+)/i) {
		$run[$#run]->{'date'} = $1;
		}
	elsif ($sect == 3 && $l =~ /^\s*(\d+)\s+(\S+)\s+([0-9,]+)\s+([0-9,]+\.[0-9,]+\s+\S+|\d+)\s+(\S+)\s+(\S+\s+\S+)\s+(\S+)\s*$/) {
		push(@done, { 'id' => $1,
			      'level' => &full_level("$2"),
			      'files' => &remove_comma("$3"),
			      'bytes' => &remove_comma("$4"),
			      'status' => $5,
			      'date' => $6,
			      'name' => &job_name("$7") });
		}
	}
return ($msg, $msg =~ /failed|error/i ? 0 : 1, \@run, \@done);
}

# get_storage_status(storage)
# Returns a status message, OK flag, running jobs and done jobs for some
# storage daemon
sub get_storage_status
{
local ($storage) = @_;
local $h = &open_console();
local $status = &console_cmd($h, "status storage=$storage");
&close_console($h);
local $msg;
if ($status =~ /Connecting\s+to\s+Storage.*\n(\n?)(.*)\n/i) {
	$msg = $2;
	}
local $sect = 0;
local (@run, @done);
local $old_style = 0;
foreach my $l (split(/\r?\n/, $status)) {
	if ($l =~ /^Running\s+Jobs/i) { $sect = 2; }
	elsif ($l =~ /^Terminated\s+Jobs/i) { $sect = 3; }

	if ($sect == 2 && $l =~ /^\s*Backup\s+Job\s+(\S+)\.(\d+\-\d+\-\S+)\s+(.*)/i) {
		push(@run, { 'name' => &job_name("$1"),
			     'status' => $3 });
		}
	elsif ($sect == 2 && $l =~ /^\s*(\S+)\s+Backup\s+job\s+(\S+)\s+JobId=(\d+)\s+Volume="(.*)"(\s+device="(.*)")?/i) {
		if (!@run || $old_style) {
			push(@run, { 'name' => $2 });
			$old_style = 1;
			}
		$run[$#run]->{'level'} = $1;
		$run[$#run]->{'id'} = $3;
		$run[$#run]->{'volume'} = $4;
		$run[$#run]->{'device'} = $6;
		}
	elsif ($sect == 3 && $l =~ /^\s*(\d+)\s+(\S+)\s+([0-9,]+)\s+([0-9,]+\.[0-9,]+\s+\S+|\d+)\s+(\S+)\s+(\S+\s+\S+)\s+(\S+)\s*$/i) {
		push(@done, { 'id' => $1,
			      'level' => &full_level("$2"),
			      'files' => &remove_comma("$3"),
			      'bytes' => &remove_comma("$4"),
			      'status' => $5,
			      'date' => $6,
			      'name' => &job_name("$7") });
		}
	}
return ($msg, $msg =~ /failed|error/i ? 0 : 1, \@run, \@done);
}

# get_pool_volumes(pool)
# Returns a list of volumes in some pool
sub get_pool_volumes
{
local ($pool) = @_;
local $h = &open_console();
local $volumes = &console_cmd($h, "llist volumes pool=$pool");
&close_console($h);
local @volumes;
local $volume;
foreach my $l (split(/\r?\n/, $volumes)) {
	if ($l =~ /^\s*(\S+):\s*(.*)/) {
		# A setting in this volume
		local ($n, $v) = (lc($1), $2);
		$volume ||= { };
		if ($v =~ /^[0-9,]+$/) {
			$v = &remove_comma($v);
			}
		elsif ($v eq "0000-00-00 00:00:00") {
			$v = undef;
			}
		$volume->{$n} = $v;
		}
	elsif ($l =~ /^\s*$/) {
		# End of this volume
		push(@volumes, $volume);
		$volume = undef;
		}
	}
push(@volumes, $volume) if ($volume && &indexof($volume, @volumes) < 0);
return @volumes;
}

# full_level(level)
# Converts a shortened backup level to a long one
sub full_level
{
local ($level) = @_;
foreach my $l (@backup_levels) {
	return $l if ($l =~ /^\Q$level\E/i);
	}
return $level;
}

sub remove_comma
{
local ($n) = @_;
$n =~ s/,//g;
if ($n =~ /^([0-9\.]+)\s*k/i) {
	$n = $1*1024;
	}
elsif ($n =~ /^([0-9\.]+)\s*M/i) {
	$n = $1*1024*1024;
	}
elsif ($n =~ /^([0-9\.]+)\s*G/i) {
	$n = $1*1024*1024*1024;
	}
elsif ($n =~ /^([0-9\.]+)\s*T/i) {
	$n = $1*1024*1024*1024*1024;
	}
return $n;
}

# job_name(name)
# Converts a job name that has had spaces replaced with _ to the real name
sub job_name
{
local ($name) = @_;
$name =~ s/_/./g;
local $conf = &get_director_config();
foreach my $j (&find("Job", $conf)) {
	local $n = &find_value("Name", $j->{'members'});
	if ($n =~ /^$name$/) {
		return $n;
		}
	}
return $name;
}

sub bacula_yesno
{
local ($id, $name, $mems) = @_;
local $v = &find_value($name, $mems);
return &ui_radio($id, $v =~ /^yes/i ? "yes" : $v =~ /^no/i ? "no" : "",
		 [ [ "yes", $text{'yes'} ],
		   [ "no", $text{'no'} ],
		   [ "", $text{'default'} ] ]);
}

# has_node_groups()
# Returns 1 if the system supports OC-Manager node groups
sub has_node_groups
{
return $config{'groupmode'} && &foreign_check("node-groups");
}

# check_node_groups()
# Returns an error message if the node group database could not be contacted
sub check_node_groups
{
if ($config{'groupmode'} eq 'oc') {
	return $text{'check_engmod'} if (!&foreign_check("node-groups"));
	return &node_groups::check_node_groups();
	}
elsif ($config{'groupmode'} eq 'webmin') {
	&foreign_require("servers", "servers-lib.pl");
	local @groups = &servers::list_all_groups();
	return @groups ? undef : $text{'check_eservers'};
	}
else {
	return undef;
	}
}

# list_node_groups()
# Returns a list of groups, each of which is a hash containing a name and
# a list of members
sub list_node_groups
{
if ($config{'groupmode'} eq 'webmin') {
	# Get list of groups from Webmin
	&foreign_require("servers", "servers-lib.pl");
	return &servers::list_all_groups();
	}
elsif ($config{'groupmode'} eq 'oc') {
	# Get list from OC database
	return &node_groups::list_node_groups();
	}
else {
	&error("Node groups not enabled!");
	}
}

sub make_dbistr
{
local ($driver, $db, $host) = @_;
local $rv;
if ($driver eq "mysql") {
	$rv = "database=$db";
	}
elsif ($driver eq "Pg") {
	$rv = "dbname=$db";
	}
else {
	$rv = $db;
	}
if ($host) {
	($host, $port) = split(/:/, $host);
	$rv .= ";host=$host";
	if ($port) {
		$rv .= ";port=$port";
		}
	}
return $rv;
}

# is_oc_object(&client|&job|name, [force-scalar])
# Returns the group name if the given object is associated with an OC group.
# In an array context, returns the job or client name too
sub is_oc_object
{
local ($object, $scalar) = @_;
local $name = ref($object) && defined($object->{'members'}) ?
		&find_value("Name", $object->{'members'}) :
	      ref($object) ? $object->{'name'}
			   : $object;
local @rv = $name =~ /^ocgroup[_\.](.*)$/ ? ( $1 ) :
       	    $name =~ /^occlientjob[_\.]([^_\.]*)[_\.](.*)$/ ? ( $1, $2 ) :
       	    $name =~ /^ocjob[_\.](.*)$/ ? ( $1 ) :
       	    $name =~ /^occlient[_\.]([^_\.]*)[_\.](.*)$/ ? ( $1, $2 ) : ( );
return wantarray && !$scalar ? @rv : $rv[0];
}

# sync_group_clients(&nodegroup)
# Update or delete all clients created from the given node group 
sub sync_group_clients
{
local ($group) = @_;
local $conf = &get_director_config();
local $parent = &get_director_config_parent();

# First delete old clients and jobs
local $gclient;
local %doneclient;
foreach my $client (&find("Client", $conf)) {
	local ($g, $c) = &is_oc_object($client);
	if ($g eq $group->{'name'} && $c) {
		# Delete this client which was generated from the group
		&save_directive($conf, $parent, $client, undef);
		$doneclient{$c} = 1;
		}
	elsif ($g eq $group->{'name'} && !$c) {
		# Found the special group definition client
		$gclient = $client;
		}
	}
foreach my $job (&find("Job", $conf)) {
	local ($j, $c) = &is_oc_object($job);
	if ($j && $c && $doneclient{$c}) {
		# Delete this job which is associated with a group's client
		&save_directive($conf, $parent, $job, undef);
		}
	}

if ($gclient) {
	# Create one client for each group
	foreach my $m (@{$group->{'members'}}) {
		local $newclient = &clone_object($gclient);
		&save_directive($conf, $newclient,
			"Name", "occlient_".$group->{'name'}."_".$m);
		&save_directive($conf, $newclient, "Address", $m);
		&save_directive($conf, $parent, undef, $newclient, 0);
		}

	# Create one real job for each group job and for each client in it!
	foreach my $job (&find_by("Client", "ocgroup_".$group->{'name'}, $conf)) {
		local $name = &is_oc_object($job);
		next if (!$name);
		foreach my $m (@{$group->{'members'}}) {
			local $newjob = { 'name' => 'Job',
					  'type' => 1,
					  'members' => [
				{ 'name' => 'Name',
				  'value' => "occlientjob_".$name."_".$m },
				{ 'name' => 'JobDefs',
				  'value' => "ocjob_".$name },
				{ 'name' => 'Client',
				  'value' => "occlient_".
					     $group->{'name'}."_".$m },
					] };
			&save_directive($conf, $parent, undef, $newjob, 0);
			}
		}
	}
}

# clone_object(&object)
# Deep-clones a Bacula object, minus any file or line details
sub clone_object
{
local ($src) = @_;
local %dest = %$src;
delete($dest{'file'});
delete($dest{'line'});
delete($dest{'eline'});
$dest{'members'} = [ ];
foreach my $sm (@{$src->{'members'}}) {
	push(@{$dest{'members'}}, &clone_object($sm));
	}
return \%dest;
}

sub find_cron_job
{
&foreign_require("cron", "cron-lib.pl");
local ($job) = grep { $_->{'command'} eq $cron_cmd } &cron::list_cron_jobs();
return $job;
}

# joblink(jobname)
# Returns a link for editing some job, if possible
sub joblink
{
if (!%joblink_jobs) {
	local $conf = &get_director_config();
	%joblink_jobs = map { $n=&find_value("Name", $_->{'members'}), 1 }
			&find("Job", $conf);
	}
local ($name) = @_;
local $job = $joblink_jobs{$name};
local ($j, $c) = &is_oc_object($name);
if (!$job) {
	return $j ? "$j ($c)" : $name;
	}
else {
	if ($j) {
		return &ui_link("edit_gjob.cgi?name=".&urlize($j)."","$j ($c)");
		}
	else {
		return &ui_link("edit_job.cgi?name=".&urlize($name)."",$name);
		}
	}
}

sub sort_by_name
{
local ($list) = @_;
@$list = sort { $na = &find_value("Name", $a->{'members'});
		$nb = &find_value("Name", $b->{'members'});
		return lc($na) cmp lc($nb) } @$list;
}

# show_tls_directives(&object)
# Print inputs for TLS directives for a director, client or storage
sub show_tls_directives
{
local ($object) = @_;
local $mems = $object->{'members'};
return if (&get_bacula_version_cached() < 1.38);
print &ui_table_hr();

print &ui_table_row($text{'tls_enable'},
		    &bacula_yesno("tls_enable", "TLS Enable", $mems));

print &ui_table_row($text{'tls_require'},
		    &bacula_yesno("tls_require", "TLS Require", $mems));

print &ui_table_row($text{'tls_verify'},
		    &bacula_yesno("tls_verify", "TLS Verify Peer", $mems));

local $cert = &find_value("TLS Certificate", $mems);
print &ui_table_row($text{'tls_cert'},
	    &ui_opt_textbox("tls_cert", $cert, 60, $text{'tls_none'})." ".
	    &file_chooser_button("tls_cert", 0), 3);

local $key = &find_value("TLS Key", $mems);
print &ui_table_row($text{'tls_key'},
	    &ui_opt_textbox("tls_key", $key, 60, $text{'tls_none'})." ".
	    &file_chooser_button("tls_key", 0), 3);

local $cacert = &find_value("TLS CA Certificate File", $mems);
print &ui_table_row($text{'tls_cacert'},
	    &ui_opt_textbox("tls_cacert", $cacert, 60, $text{'tls_none'})." ".
	    &file_chooser_button("tls_cacert", 0), 3);
}

# parse_tls_directives(&config, &object, indent)
sub parse_tls_directives
{
local ($conf, $object, $indent) = @_;
return if (&get_bacula_version_cached() < 1.38);

&save_directive($conf, $object, "TLS Enable", $in{'tls_enable'} || undef,
		$indent);
&save_directive($conf, $object, "TLS Require", $in{'tls_require'} || undef,
		$indent);
&save_directive($conf, $object, "TLS Verify Peer", $in{'tls_verify'} || undef,
		$indent);

$in{'tls_cert_def'} || -r $in{'tls_cert'} || &error($text{'tls_ecert'});
&save_directive($conf, $object, "TLS Certificate",
		$text{'tls_ecert_def'} ? undef : $in{'tls_cert'}, $indent);

$in{'tls_key_def'} || -r $in{'tls_key'} || &error($text{'tls_ekey'});
&save_directive($conf, $object, "TLS Key",
		$text{'tls_ekey_def'} ? undef : $in{'tls_key'}, $indent);

$in{'tls_cacert_def'} || -r $in{'tls_cacert'} || &error($text{'tls_ecacert'});
&save_directive($conf, $object, "TLS CA Certificate File",
		$text{'tls_ecacert_def'} ? undef : $in{'tls_cacert'}, $indent);

if ($in{'tls_enable'} eq 'yes' &&
    ($in{'tls_cert_def'} || $in{'tls_key_def'} || $in{'tls_cacert_def'})) {
	&error($text{'tls_ecerts'});
	}

if (!$in{'tls_key_def'}) {
	&foreign_require("webmin", "webmin-lib.pl");
	&webmin::validate_key_cert($in{'tls_key'},
			$in{'tls_cert_def'} ? undef : $in{'tls_cert'});
	}

}

# schedule_chooser_button(name)
# Returns a button for choosing a Bacula schedule in a popup window
sub schedule_chooser_button
{
local ($name) = @_;
return "<input type=button onClick='ifield = form.$name; schedule = window.open(\"schedule_chooser.cgi?schedule=\"+escape(ifield.value), \"schedule\", \"toolbar=no,menubar=no,scrollbars=no,width=600,height=600\"); schedule.ifield = ifield; window.ifield = ifield;' value=\"...\">\n";
}

# parse_schedule(string)
# Returns an object containing details of a schedule, or undef if not parseable
# XXX hourly at mins
sub parse_schedule
{
local ($str) = @_;
local @w = split(/\s+/, $str);
local $rv = { };

# Look for month spec
if ($w[0] eq "monthly") {
	# Monthyl
	$rv->{'months_all'} = 1;
	shift(@w);
	}
elsif ($w[0] =~ /^(\S+)\-(\S+)$/ &&
       defined(&is_month($1)) && defined(&is_month($2))) {
	# A month range
	$rv->{'months'} = [ &is_month($1) .. &is_month($2) ];
	shift(@w);
	}
elsif (defined(&is_month($w[0]))) {
	# One month
	$rv->{'months'} = [ &is_month($w[0]) ];
	shift(@w);
	}
else {
	$rv->{'months_all'} = 2;
	}

# Look for days of month spec
if ($w[0] eq "on") {
	shift(@w);
	}
if ($w[0] =~ /^(\d+)\-(\d+)$/) {
	$rv->{'days'} = [ $1 .. $2 ];
	shift(@w);
	}
elsif ($w[0] =~ /^\d+$/) {
	$rv->{'days'} = [ $w[0] ];
	shift(@w);
	}
else {
	$rv->{'days_all'} = 1;
	}

# Look for days of week
if ($w[0] =~ /^(\S+)\-(\S+)$/ &&
       defined(&is_nth($1)) && defined(&is_nth($2))) {
	# nth weekday range
	$rv->{'weekdaynums'} = [ &is_nth($1) .. &is_nth($2) ];
	shift(@w);
	}
elsif (defined(&is_nth($w[0]))) {
	# nth weekday of month
	$rv->{'weekdaynums'} = [ &is_nth($w[0]) ];
	shift(@w);
	}
else {
	# Any weekday num
	$rv->{'weekdaynums_all'} = 1;
	}
if ($w[0] =~ /^(\S+)\-(\S+)$/ &&
    defined(&is_weekday($1)) && defined(&is_weekday($2))) {
	# Day or week range
	$rv->{'weekdays'} = [ &is_weekday($1) .. &is_weekday($2) ];
	shift(@w);
	}
elsif (defined(&is_weekday($w[0]))) {
	# One day of week
	$rv->{'weekdays'} = [ &is_weekday($w[0]) ];
	shift(@w);
	}
else {
	# Any weekday
	return "Missing weekday when weekday number was specified"
		if (!$rv->{'weekdaynums_all'});
	$rv->{'weekdays_all'} = 1;
	}

# Look for time of day
if ($w[0] eq "at") {
	shift(@w);
	}
if ($w[0] =~ /^(\d+):(\d+)$/) {
	$rv->{'hour'} = $1;
	$rv->{'minute'} = $2;
	}
elsif ($w[0] =~ /^(\d+):(\d+)(am|pm)$/i) {
	$rv->{'hour'} = $1;
	$rv->{'minute'} = $2;
	$rv->{'hour'} += 12 if (lc($3) eq 'pm');
	}
else {
	return "Missing hour:minute spec";
	}

return $rv;
}

sub is_month
{
local $m = lc(substr($_[0], 0, 3));
return $month_to_number_map{$m};
}

sub is_nth
{
local $n = lc($_[0]);
return $n eq "1st" || $n eq "first" ? 1 :
       $n eq "2nd" || $n eq "second" ? 2 :
       $n eq "3rd" || $n eq "third" ? 3 :
       $n eq "4th" || $n eq "fourth" ? 4 :
       $n eq "5th" || $n eq "fifth" ? 5 : undef;
}

sub is_weekday
{
local $w = lc(substr($_[0], 0, 3));
return $w eq "sun" ? 0 :
       $w eq "mon" ? 1 :
       $w eq "tue" ? 2 :
       $w eq "wed" ? 3 :
       $w eq "thu" ? 4 :
       $w eq "fri" ? 5 :
       $w eq "sat" ? 6 : undef;
}

# join_schedule(&sched)
# Converts a schedule object into a string
sub join_schedule
{
local ($sched) = @_;
local @w;

if (!$sched->{'months_all'}) {
	local $r = &make_range($sched->{'months'}, \%number_to_month_map);
	defined($r) || &error($text{'chooser_emonthsrange'});
	push(@w, $r);
	}

if (!$sched->{'days_all'}) {
	local %days_map = map { $_, $_ } (1 .. 31);
	local $r = &make_range($sched->{'days'}, \%days_map);
	defined($r) || &error($text{'chooser_edaysrange'});
	push(@w, "on", $r);
	}

if (!$sched->{'weekdaynums_all'}) {
	local %weekdaynums_map = ( 1 => '1st', 2 => '2nd', 3 => '3rd',
				   4 => '4th', 5 => '5th' );
	local $r = &make_range($sched->{'weekdaynums'}, \%weekdaynums_map);
	defined($r) || &error($text{'chooser_eweekdaynumsrange'});
	push(@w, $r);
	}

if (!$sched->{'weekdays_all'}) {
	local %weekdays_map = ( 0 => 'sun', 1 => 'mon', 2 => 'tue',
			   3 => 'wed', 4 => 'thu', 5 => 'fri', 6 => 'sat' );
	local $r = &make_range($sched->{'weekdays'}, \%weekdays_map);
	defined($r) || &error($text{'chooser_eweekdaysrange'});
	push(@w, $r);
	}

push(@w, "at");
push(@w, $sched->{'hour'}.":".$sched->{'minute'});

return join(" ", @w);
}

# make_range(&nums, &map)
sub make_range
{
local ($nums, $map) = @_;
if (scalar(@$nums) == 1) {
	return $map->{$nums->[0]};
	}
@$nums = sort { $a <=> $b } @$nums;
$prev = undef;
foreach my $n (@$nums) {
	if (defined($prev) && $prev != $n-1) {
		return undef;
		}
	$prev = $n;
	}
return $map->{$nums->[0]}."-".$map->{$nums->[@$nums-1]};
}

# date_to_unix(string)
# Converts a MySQL date string to a Unix time_t
sub date_to_unix
{
local ($str) = @_;
if ($str =~ /^(\d{4})\-(\d\d)\-(\d\d)\s+(\d\d):(\d\d):(\d\d)$/) {
	# MySQL time
	return timelocal($6, $5, $4, $3, $2-1, $1-1900);
	}
return undef;
}

# extract_schedule(run)
# Given a schedule Run string like Level=Full Pool=Monthly 1st sat at 03:05, 
# returns a hash ref of the tags and the schedule.
sub extract_schedule
{
local ($run) = @_;
local %tags;
while($run =~ s/^(\S+)=(\S+)\s+//) {
	$tags{$1} = $2;
	}
if (!$tags{'Level'}) {
	$run =~ s/^(\S+)\s+//;
	$tags{'Level'} = $1;
	}
return ( \%tags, $run );
}

1;

