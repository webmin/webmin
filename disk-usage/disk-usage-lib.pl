# Functions for getting usage

do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';

$usage_tree_file = "$module_config_directory/tree";
$heiropen_file = "$module_config_directory/heiropen";
$cron_cmd = "$module_config_directory/usage.pl";

# build_root_usage_tree(&dirs)
# Returns a usage tree from / containing all the specified directories
sub build_root_usage_tree
{
local $root = { 'dir' => '/',
		'total' => 0,
		'files' => 0 };
foreach my $dir (@{$_[0]}) {
	# No need to do a directory that has already been done by a parent
	local $already = &find_in_tree($root, $dir);
	next if ($already && $dir ne "/");

	local $tree = &build_usage_tree($dir);
	if ($dir eq "/") {
		$root = $tree;
		}
	else {
		# Insert into root at correct location
		while(1) {
			$tree->{'dir'} =~ /^(.*)\/(.*)$/;
			local $pdir = $1 || "/";
			local $file = $2;
			local $par = &find_in_tree($root, $pdir);
			if ($par) {
				# Found a parent .. link to it
				push(@{$par->{'subs'}}, $tree);
				$tree->{'parent'} = $parent;

				# Increase the totals for all parents
				while($par) {
					$par->{'total'} += $tree->{'total'};
					$par = $par->{'parent'};
					}
				last;
				}
			else {
				# Need to make up a parent
				$par = { 'dir' => $pdir, 'subs' => [ $tree ],
					 'total' => $tree->{'total'},
					 'files' => 0 };
				$tree->{'parent'} = $par;
				$tree = $par;
				}
			}
		}
	}
return $root;
}

# build_usage_tree(dir)
# Given a base directory, returns a structure containing details about it and
# all sub-directories
sub build_usage_tree
{
local ($dir) = @_;
local ($total, $files) = (0, 0);
opendir(DIR, $dir);
local @files = readdir(DIR);
closedir(DIR);
local $rv = { 'dir' => $dir, 'subs' => [ ] };
local @pst = stat($dir);

local $skip = &get_skip_dirs();
foreach my $f (@files) {
	next if ($f eq "." || $f eq "..");
	local $path = $dir eq "/" ? "/$f" : "$dir/$f";
	next if ($skip->{$path});
	local @st = lstat($path);
	if ($config{'bsize'}) {
		$total += $st[12]*$config{'bsize'};
		$files += $st[12]*$config{'bsize'};
		}
	else {
		$total += $st[7];
		$files += $st[7];
		}
	if ($config{'xdev'} && $st[0] != $pst[0]) {
		next;	# Don't go to another filesystem
		}
	if (-d _ && !-l _) {
		# A directory .. recurse into it
		local $subdir = &build_usage_tree($path, $rv);
		$subdir->{'parent'} = $rv;
		$total += $subdir->{'total'};
		push(@{$rv->{'subs'}}, $subdir);
		}
	}
$rv->{'total'} = $total;
$rv->{'files'} = $files;
return $rv;
}

# get_usage_tree()
sub get_usage_tree
{
local (%tree, %pmap);
&read_file($usage_tree_file, \%tree) || return undef;
foreach my $k (keys %tree) {
	if ($k ne "/" && $k =~ /^(.*)\/(.*)$/) {
		local $dir = $1 || "/";
		local $file = $2;
		push(@{$pmap{$dir}}, $k);
		}
	}
return &hash_to_tree($tree{'root'}, \%tree, \%pmap);
}

# hash_to_tree(dir, &hash, &parentmap)
sub hash_to_tree
{
local ($dir, $hash, $pmap) = @_;
local $rv = { 'dir' => $dir, 'subs' => [ ] };
($rv->{'total'}, $rv->{'files'}) = split(/ /, $hash->{$dir});
foreach my $subdir (@{$pmap->{$dir}}) {
	local $substr = &hash_to_tree($subdir, $hash, $pmap);
	$substr->{'parent'} = $rv;
	push(@{$rv->{'subs'}}, $substr);
	}
return $rv;
}

# save_usage_tree(&tree)
sub save_usage_tree
{
local ($dir) = @_;
local %tree;
&tree_to_hash($dir, \%tree);
$tree{'root'} = $dir->{'dir'};
&write_file($usage_tree_file, \%tree);
}

# tree_to_hash(&dir, &hash)
# Adds to the hash entries for some tree node and sub-nodes
sub tree_to_hash
{
local ($dir, $hash) = @_;
$hash->{$dir->{'dir'}} = $dir->{'total'}." ".$dir->{'files'};
foreach my $subdir (@{$dir->{'subs'}}) {
	&tree_to_hash($subdir, $hash);
	}
}

# find_in_tree(&tree, dir)
# Returns the node for some directory, or undef
sub find_in_tree
{
local ($tree, $dir) = @_;
return $tree if ($tree->{'dir'} eq $dir);
if ($tree->{'dir'} eq "/" ||
    $dir =~ /^$tree->{'dir'}\//) {
	foreach my $subdir (@{$tree->{'subs'}}) {
		local $found = &find_in_tree($subdir, $dir);
		return $found if ($found);
		}
	}
return undef;
}

# get_heiropen()
# Returns an array of open categories
sub get_heiropen
{
open(HEIROPEN, $heiropen_file);
local @heiropen = <HEIROPEN>;
chop(@heiropen);
close(HEIROPEN);
return @heiropen;
}

# save_heiropen(&heir)
sub save_heiropen
{
&open_tempfile(HEIR, ">$heiropen_file");
foreach $h (@{$_[0]}) {
	&print_tempfile(HEIR, $h,"\n");
	}
&close_tempfile(HEIR);
}

sub find_cron_job
{
local @jobs = &cron::list_cron_jobs();
local ($job) = grep { $_->{'user'} eq 'root' &&
		      $_->{'command'} eq $cron_cmd } @jobs;
return $job;
}

# get_skip_dirs()
# Returns a hash reference of directories to skip, based on the skip list
# and filesystems
sub get_skip_dirs
{
if (!%skip_cache) {
	%skip_cache = map { $_, 1 } split(/\t+/, $config{'skip'});
	if (&foreign_check("mount")) {
		&foreign_require("mount", "mount-lib.pl");
		local %fsskip = map { $_, 1 } split(/\s+/, $config{'fs'});
		foreach my $m (&mount::list_mounted()) {
			if ($fsskip{$m->[2]}) {
				$skip_cache{$m->[0]} = 1;
				}
			}
		}
	}
return \%skip_cache;
}

1;

