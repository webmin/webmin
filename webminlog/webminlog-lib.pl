# webminlog-lib.pl
# XXX file rollback
#	XXX should we capture all files, or just those changed?
#	XXX what about commands?

do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';
%access = &get_module_acl();
%access_mods = map { $_, 1 } split(/\s+/, $access{'mods'});
%access_users = map { $_, 1 } split(/\s+/, $access{'users'});

sub parse_logline
{
if ($_[0] =~ /^(\d+)\.(\S+)\s+\[.*\]\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+"([^"]+)"\s+"([^"]+)"\s+"([^"]+)"(.*)/ ||
    $_[0] =~ /^(\d+)\.(\S+)\s+\[.*\]\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)(.*)/) {
	local $rv = { 'time' => $1, 'id' => "$1.$2",
		      'user' => $3, 'sid' => $4,
		      'ip' => $5, 'module' => $6,
		      'script' => $7, 'action' => $8,
		      'type' => $9, 'object' => $10 };
	local %param;
	local $p = $11;
	while($p =~ /^\s*([^=\s]+)='([^']*)'(.*)$/) {
		if (defined($param{$1})) {
			$param{$1} .= "\0".$2;
			}
		else {
			$param{$1} = $2;
			}
		$p = $3;
		}
	foreach $k (keys %param) {
		$param{$k} =~ s/%(..)/pack("c",hex($1))/ge;
		}
	$rv->{'param'} = \%param;
	if ($rv->{'script'} =~ /^(\S+):(\S+)$/) {
		$rv->{'script'} = $2;
		$rv->{'webmin'} = $1;
		}
	return $rv;
	}
else {
	return undef;
	}
}

# list_diffs(&action)
# Returns details of file changes made by this action
sub list_diffs
{
local $i = 0;
local @rv;
local $base = "$ENV{'WEBMIN_VAR'}/diffs/$act->{'id'}";
local @files = &expand_base_dir($base);

# Read the diff files
foreach my $file (@files) {
        local ($type, $object, $diff, $input);
	open(DIFF, $file);
        local $line = <DIFF>;
        while(<DIFF>) { $diff .= $_; }
        close(DIFF);
	if ($line =~ /^(\/.*)/) {
                $type = 'modify'; $object = $1;
                }
        elsif ($line =~ /^(\S+)\s+(.*)/) {
                $type = $1; $object = $2;
                }
	if ($type eq "exec") {
		open(INPUT, $file.".input");
		while(<INPUT>) {
			$input .= $_;
			}
		close(INPUT);
		}
	push(@rv, { 'type' => $type,
		    'object' => $object,
		    'diff' => $diff,
		    'input' => $input } );
	$i++;
	}
return @rv;
}

# list_files(&action)
# Returns details of original files before this action was taken
sub list_files
{
local $i = 0;
local @rv;
local $base = "$ENV{'WEBMIN_VAR'}/files/$act->{'id'}";
local @files = &expand_base_dir($base);
foreach my $file (@files) {
        local ($type, $object, $data);
	open(FILE, $file);
        local $line = <FILE>;
	$line =~ s/\r|\n//g;
        while(<FILE>) { $data .= $_; }
        close(FILE);
	if ($line =~ /^(\S+)\s+(.*)/) {
		$type = $1;
		$file = $2;
		}
	elsif ($line =~ /^\s+(.*)/) {
		$type = -1;
		$file = $1;
		}
	else {
		next;
		}
	push(@rv, { 'type' => $type,
		    'file' => $file,
		    'data' => $data });
	$i++;
	}
return @rv;
}

# expand_base_dir(base)
# Finds files either under some dir, or starting with some path
sub expand_base_dir
{
local ($base) = @_;
local @files;
if (-d $base) {
	# Find files in the dir
	opendir(DIR, $base);
	@files = map { "$base/$_" } sort { $a <=> $b }
			grep { $_ =~ /^\d+$/ } readdir(DIR);
	closedir(DIR);
	}
else {
	# Files are those that start with id
	$i = 0;
	while(-r "$base.$i") {
		push(@files, "$base.$i");
		$i++;
		}
	}
return @files;
}

# can_user(username)
sub can_user
{
return $access_users{'*'} || $access_users{$_[0]};
}

# can_mod(module)
sub can_mod
{
return $access_mods{'*'} || $access_mods{$_[0]};
}

# get_action(id)
# Returns the structure for some action
sub get_action
{
local %index;
&build_log_index(\%index);
local $act;
open(LOG, $webmin_logfile);
local @idx = split(/\s+/, $index{$_[0]});
seek(LOG, $idx[0], 0);
local $line = <LOG>;
local $act = &parse_logline($line);
close(LOG);
return $act->{'id'} eq $_[0] ? $act : undef;
}

# build_log_index(&index)
# Updates the given hash with mappings between action IDs and file positions
sub build_log_index
{
local ($index) = @_;
local $ifile = "$module_config_directory/logindex";
dbmopen(%$index, $ifile, 0600);
local @st = stat($webmin_logfile);
if ($st[9] > $index->{'lastchange'}) {
	# Log has changed .. perhaps need to rebuild
	open(LOG, $webmin_logfile);
	if ($index->{'lastsize'} && $st[7] >= $index->{'lastsize'}) {
		# Gotten bigger .. just add new lines
		seek(LOG, $index->{'lastpos'}, 0);
		}
	else {
		# Smaller! Need to rebuild from start
		%$index = ( 'lastpos' => 0 );
		}
	while(<LOG>) {
		if ($act = &parse_logline($_)) {
			$index->{$act->{'id'}} = $index->{'lastpos'}." ".
						 $act->{'time'}." ".
						 $act->{'user'}." ".
						 $act->{'module'}." ".
						 $act->{'sid'};
			}
		$index->{'lastpos'} += length($_);
		}
	close(LOG);
	$index->{'lastsize'} = $st[7];
	$index->{'lastchange'} = $st[9];
	}
}

1;

