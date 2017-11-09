# export-lib.pl
# Common functions for exports file

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
do "hpux-lib.pl";
%access = &get_module_acl();

# parse_options($options, \%options)
# Parse a mount options string like rw=foo,nosuid,... into a associative
# options array. Parts with no value are given an empty string as the value
# useful for HPUX and DFS - perhaps for linux, too
sub parse_options
{
local($opt);
foreach $opt (split(/,/, $_[0])) {
        if ($opt =~ /^([^=]+)=(.*)$/) {
                $_[1]->{$1} = $2;
                }
        else {
                $_[1]->{$opt} = "";
                }
        }
}


# join_options(\%options)
# Returns a list of options from a options array, in the form used in
# the exports file
# useful for HPUX and DFS - perhaps for linux, too
sub join_options
{
local $o = $_[0];
local(@list, $k);
foreach $k (keys %$o) {
        if ($_[0]->{$k} eq "") {
                push(@list, $k);
                }
        else {
                push(@list, "$k=$_[0]->{$k}");
                }
        }
return join(',', @list);
}

# create_export(&export)
sub create_export
{
open(EXP, ">>$config{'exports_file'}");
print EXP &make_exports_line($_[0]),"\n";
close(EXP);
}


# modify_export(&export, &old)
sub modify_export
{
local @exps = &list_exports();
local @same = grep { $_->{'line'} eq $_[1]->{'line'} } @exps;
local $lref = &read_file_lines($config{'exports_file'});
if ($_[0]->{'dir'} eq $_[1]->{'dir'} &&
    $_[0]->{'active'} == $_[1]->{'active'} || @same == 1) {
        # directory not changed, or on a line of it's own
        splice(@same, &indexof($_[1],@same), 1, $_[0]);
        splice(@$lref, $_[1]->{'line'}, $_[1]->{'eline'}-$_[1]->{'line'}+1,
               &make_exports_line(@same));
        }
else {
        # move to a line of it's own
        splice(@same, &indexof($_[1],@same), 1);
        splice(@$lref, $_[1]->{'line'}, $_[1]->{'eline'}-$_[1]->{'line'}+1,
               &make_exports_line(@same));
        push(@$lref, &make_exports_line($_[0]));
        }
&flush_file_lines();
}


# delete_export(&export)
# Delete an existing export
sub delete_export
{
local @exps = &list_exports();
local @same = grep { $_ ne $_[0] && $_->{'line'} eq $_[0]->{'line'} } @exps;
local $lref = &read_file_lines($config{'exports_file'});
if (@same) {
        # other exports on the same line.. cannot totally delete
        splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'}-$_[0]->{'line'}+1,
               &make_exports_line(@same));
        map { $_->{'line'} = $_->{'eline'} = $_[0]->{'line'} } @same;
        }
else {
        # remove export line
        splice(@$lref, $_[0]->{'line'}, $_[0]->{'eline'}-$_[0]->{'line'}+1);
        }
@list_exports_cache = grep { $_ ne $_[0] } @list_exports_cache;
&flush_file_lines();
}


# check_hosts(option, hostlist)
# Die if any of the listed hosts does not exist
# or no hosts listed for specified option
sub check_hosts
{
local @h = split(/\s+/, $_[1]);

if (!@h) {
        &error(&text('save_enohost', $_[0]));
        }

foreach (@h) {
        if (!&to_ipaddress($_)) { &error(&text('save_ehost', $_, $_[0])); }
        }
}

sub has_nfs_commands
{
return !&has_command("rpc.nfsd") && !&has_command("nfsd") &&
       !&has_command("rpc.knfsd") ? 0 : 1;
}

1;

