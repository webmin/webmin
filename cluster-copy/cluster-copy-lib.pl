# cluster-copy-lib.pl
# XXX add to released modules list

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
&foreign_require("cron", "cron-lib.pl");
&foreign_require("mailboxes", "mailboxes-lib.pl");

$cron_cmd = "$module_config_directory/copy.pl";
$copies_dir = "$module_config_directory/copies";

# list_copies()
# Returns an array of scheduled copies to multiple servers
sub list_copies
{
local (@rv, $f);
opendir(DIR, $copies_dir);
foreach $f (sort { $a cmp $b } readdir(DIR)) {
	next if ($f !~ /^(\S+)\.copy$/);
	push(@rv, &get_copy($1));
	}
closedir(DIR);
return @rv;
}

# get_copy(id)
sub get_copy
{
local %copy;
&read_file("$copies_dir/$_[0].copy", \%copy) || return undef;
$copy{'id'} = $_[0];
if (!defined($copy{'email'})) {
	# compat - continue email to root
	$copy{'email'} = "root";
	}
return \%copy;
}

# save_copy(&copy)
sub save_copy
{
$_[0]->{'id'} ||= time().$$;
mkdir($copies_dir, 0700);
&lock_file("$copies_dir/$_[0]->{'id'}.copy");
&write_file("$copies_dir/$_[0]->{'id'}.copy", $_[0]);
&unlock_file("$copies_dir/$_[0]->{'id'}.copy");
}

# delete_copy(&copy)
sub delete_copy
{
&lock_file("$copies_dir/$_[0]->{'id'}.copy");
unlink("$copies_dir/$_[0]->{'id'}.copy");
&unlock_file("$copies_dir/$_[0]->{'id'}.copy");
}

# run_cluster_job(&job, &callback)
# Runs a cluster cron job on all configured servers, and for each result calls
# the callback function with parameters 0/1, a server object, and the list of
# files copied or an error message
sub run_cluster_job
{
local @rv;
local $func = $_[1];

# Work out which servers to run on
&foreign_require("servers", "servers-lib.pl");
local @servers = &servers::list_servers_sorted();
local @groups = &servers::list_all_groups(\@servers);
local @run;
foreach $s (split(/\s+/, $_[0]->{'servers'})) {
	if ($s =~ /^group_(.*)$/) {
		# All members of a group
		($group) = grep { $_->{'name'} eq $1 } @groups;
		foreach $m (@{$group->{'members'}}) {
			push(@run, grep { $_->{'host'} eq $m && $_->{'user'} }
					@servers);
			}
		}
	elsif ($s eq '*') {
		# This server
		push(@run, ( { 'desc' => $text{'edit_this'} } ));
		}
	elsif ($s eq 'ALL') {
		# All servers with login
		push(@run, grep { $_->{'user'} } @servers);
		}
	else {
		# A single remote server
		push(@run, grep { $_->{'host'} eq $s } @servers);
		}
	}
@run = &unique(@run);

# Setup error handler for down hosts
sub inst_error
{
$inst_error_msg = join("", @_);
}
&remote_error_setup(\&inst_error);

# Run the pre command on local
if ($_[0]->{'before'} && $_[0]->{'beforelocal'}) {
	&system_logged("$_[0]->{'before'} >/dev/null 2>&1");
	}

# Run one each one in parallel and display the output
$p = 0;
foreach $s (@run) {
	local ($rh = "READ$p", $wh = "WRITE$p");
	pipe($rh, $wh);
	select($wh); $| = 1; select(STDOUT);
	if (!fork()) {
		# Run the command in a subprocess
		close($rh);

		if (!$s->{'fast'}) {
			print $wh &serialise_variable(
				[ 0, "Fast RPC mode must be enabled ".
				     "for copies to work" ]);
			exit;
			}

		&remote_foreign_require($s->{'host'}, "webmin",
					"webmin-lib.pl");
		if ($inst_error_msg) {
			# Failed to contact host ..
			print $wh &serialise_variable([ 0, $inst_error_msg ]);
			exit;
			}

		# Run the pre command on remote
		local $bout;
		if ($_[0]->{'before'} && !$_[0]->{'beforelocal'}) {
			$bout = &remote_foreign_call($s->{'host'},
				"webmin", "backquote_logged", $_[0]->{'before'});
			}

		# Work out which files to transfer, and which directories
		# to create
		local @allnames = split(/\t+/, $_[0]->{'files'});
		local (@allfiles, @alldirs);
		foreach $f (@allnames) {
			if (-d $f) {
				# Expand this directory
				&expand_dir($f, \@allfiles, \@alldirs);
				}
			else {
				push(@allfiles, $f);
				}
			}

		# Create each of the needed directories
		local (@errs, $d);
		foreach $d (@alldirs) {
			local $dest;
			if ($_[0]->{'dmode'}) {
				# Relative to directory
				$d =~ /([^\/]+)$/;
				$dest = $_[0]->{'dest'}."/".$1;
				}
			else {
				# Full path under directory
				$dest = $_[0]->{'dest'}.$d;
				}
			local $qdest = quotemeta($dest);
			local $rmd = &remote_eval($s->{'host'}, "webmin",
				     "-d \"$qdest\" ? \"already\" : &make_dir(\"$qdest\", 0755, 1) ? undef : \$!");
			if (!$rmd) {
				push(@dirs, $d);
				}
			elsif ($rmd ne "already") {
				push(@errs, [ $d, "Failed to create $dest : $rmd" ]);
				}
			}

		# Transfer each of the files, and make sure each was done OK
		local (@files, $f);
		foreach $f (@allfiles) {
			local $dest;
			if ($_[0]->{'dmode'}) {
				# Relative to directory
				$f =~ /([^\/]+)$/;
				$dest = $_[0]->{'dest'}."/".$1;
				}
			else {
				# Full path under directory
				$dest = $_[0]->{'dest'}.$f;
				}
			if (!-r $f) {
				push(@errs, [ $f, "Source file not found" ]);
				next;
				}
			if (&simplify_path($f) eq &simplify_path($dest) &&
			    $s->{'id'} == 0) {
				push(@errs, [ $f, "Cannot overwrite same file on this server" ]);
				next;
				}
			&remote_write($s->{'host'}, $f, $dest);
			if ($inst_error_msg) {
				push(@errs, [ $f, "Copy failed : $inst_error_msg" ]);
				next;
				}
			local $qdest = quotemeta($dest);
			local $rst = &remote_eval($s->{'host'}, "webmin",
						   "[ stat(\"$qdest\") ]");
			local @st = stat($f);
			if ($st[7] == $rst->[7]) {
				push(@files, $f);
				}
			else {
				push(@errs, [ $f, "Copy was incomplete" ]);
				}

			# Preserve file permissions
			&remote_foreign_call($s->{'host'}, "webmin",
				"set_ownership_permissions", $st[4], $st[5],
				$st[2] & 0777, $dest);
			}

		# Run the post command on remote
		local $out;
		if ($_[0]->{'cmd'} && !$_[0]->{'cmdlocal'}) {
			$out = &remote_foreign_call($s->{'host'},
				"webmin", "backquote_logged", $_[0]->{'cmd'});
			}

		print $wh &serialise_variable([ 1, \@files, \@errs, \@dirs,
						$out, $bout ]);
		close($wh);
		exit;
		}
	close($wh);
	$p++;
	}

# Get back all the results
$p = 0;
foreach $s (@run) {
	local $rh = "READ$p";
	local $line = <$rh>;
	close($rh);
	local $rv = &unserialise_variable($line);

	if (!$line) {
		&$func(0, $s, "Unknown reason");
		}
	else {
		&$func($rv->[0], $s, $rv->[1], $rv->[2], $rv->[3],
		       $rv->[4], $rv->[5]);
		}
	$p++;
	}
unlink($ltemp);

# Run the post command on local
if ($_[0]->{'cmd'} && $_[0]->{'cmdlocal'}) {
	&system_logged("$_[0]->{'cmd'} >/dev/null 2>&1");
	}

return @run;
}

# find_cron_job(&copy)
sub find_cron_job
{
local @jobs = &cron::list_cron_jobs();
local ($job) = grep { $_->{'user'} eq 'root' &&
		$_->{'command'} eq "$cron_cmd $_[0]->{'id'}" } @jobs;
return $job;
}

# expand_dir(dir, &files, &dirs)
sub expand_dir
{
push(@{$_[2]}, $_[0]);
opendir(DIR, $_[0]);
local $f;
foreach $f (readdir(DIR)) {
	next if ($f eq "." || $f eq "..");
	local $fp = "$_[0]/$f";
	next if (-l $fp);
	if (-d $fp) {
		&expand_dir($fp, $_[1], $_[2]);
		}
	else {
		push(@{$_[1]}, $fp);
		}
	}
closedir(DIR);
}

1;

