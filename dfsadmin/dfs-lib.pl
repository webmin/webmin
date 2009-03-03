# dfs-lib.pl
# Common functions for managing dfstab files

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
%access = &get_module_acl();

$default_type = 'nfs';
if ($config{'fstypes_file'} && open(TYPES, $config{'fstypes_file'})) {
	if (<TYPES> =~ /^(\S+)/) {
		$default_type = $1;
		}
	close(TYPES);
	}
%access = &get_module_acl();

# list_shares()
# Returns a list of structures containing share details
sub list_shares
{
local $lnum = 0;
local @rv;
open(DFS, $config{'dfstab_file'});
while(<DFS>) {
	s/\r|\n//g; s/#.*$//;
	if (/^\s*\S*share\s+(.*)/) {
		# Found a share line
		local $share = { 'line' => $lnum,
				 'index' => scalar(@rv) };
		local $line = $1;
		while($line =~ /\\$/) {
			$_ = <DFS>;
			s/\r|\n//g; s/#.*$//;
			$line =~ s/\\$//;
			$line .= $_;
			$lnum++;
			}
		$share->{'eline'} = $lnum;
		if ($line =~ /\s(\/\S+)/) {
			$share->{'dir'} = $1;
			}
		if ($line =~ /-d\s+"([^"]+)"/) { $share->{'desc'} = $1; }
		elsif ($line =~ /-d\s+(\S+)/) { $share->{'desc'} = $1; }
		if ($line =~ /-o\s+"([^"]+)"/) { $share->{'opts'} = $1; }
		elsif ($line =~ /-o\s+(\S+)/) { $share->{'opts'} = $1; }
		if ($line =~ /\s-F\s+(\S+)/) { $share->{'type'} = $1; }
		else { $share->{'type'} = $default_type; }
		push(@rv, $share);
		}
	$lnum++;
	}
close(DFS);
return @rv;
}

# create_share(&share)
# Add a new share to the dfstab file
sub create_share
{
&open_tempfile(DFS, ">> $config{dfstab_file}");
&print_tempfile(DFS, &share_line($_[0]),"\n");
&close_tempfile(DFS);
}

# modify_share(&share)
# Modify an existing share
sub modify_share
{
local $lref = &read_file_lines($config{'dfstab_file'});
splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1,
       &share_line($_[0]));
&flush_file_lines();
}

# share_line(&share)
sub share_line
{
local $s = "share";
$s .= " -d \"$_[0]->{'desc'}\"" if ($_[0]->{'desc'});
$s .= " -o $_[0]->{'opts'}" if ($_[0]->{'opts'});
$s .= " -F $_[0]->{'type'}" if ($_[0]->{'type'} &&
				$_[0]->{'type'} ne $default_type);
$s .= " $_[0]->{'dir'}";
return $s;
}

# delete_share(&share)
# Delete the share for a particular directory
sub delete_share
{
local $lref = &read_file_lines($config{'dfstab_file'});
splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'} - $_[0]->{'line'} + 1);
&flush_file_lines();
}

# parse_options(string)
# Parse a mount options string like rw=foo,nosuid,... into the associative
# array %options. Parts with no value are given an empty string as the value
sub parse_options
{
local($opt);
undef(%options);
foreach $opt (split(/,/, $_[0])) {
	if ($opt =~ /^([^=]+)=(.*)$/) {
		$options{$1} = $2;
		}
	else {
		$options{$opt} = "";
		}
	}
return \%options;
}

# join_options([&options])
# Returns a list of options from the %options array, in the form used in
# the dfstab file
sub join_options
{
local $o = $_[0] ? $_[0] : \%options;
local(@list, $k);
foreach $k (keys %$o) {
	if ($o->{$k} eq "") {
		push(@list, $k);
		}
	else {
		push(@list, "$k=$o->{$k}");
		}
	}
return join(',', @list);
}

# apply_configuration()
# Apply the NFS configuration, returning undef on success or an error message
# on failure
sub apply_configuration
{
local $temp = &transname();
&system_logged("$config{unshare_all_command} >/dev/null 2>&1");
&system_logged("$config{share_all_command} >/dev/null 2>$temp");
local $why = `/bin/cat $temp`;
unlink($temp);
if ($why =~ /\S+/) {
	return $why;
	}
return undef;
}

1;

