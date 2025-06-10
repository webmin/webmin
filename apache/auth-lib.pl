# auth-lib.pl
# Functions for editing text and dbm user files

# list_authusers(file)
# Returns an array of user names from the given file
sub list_authusers
{
local($_, @rv);
&open_readfile(HTPASSWD, $_[0]);
while(<HTPASSWD>) {
	if (/^(\S+):(\S*)/) { push(@rv, $1); }
	}
close(HTPASSWD);
return @rv;
}

# get_authuser(file, name)
sub get_authuser
{
local($_, $rv);
&open_readfile(HTPASSWD, $_[0]);
while(<HTPASSWD>) {
	if (/^(\S+):(\S*)/ && $1 eq $_[1]) {
		$rv = { 'user' => $1 , 'pass' => $2 };
		}
	}
close(HTPASSWD);
return $rv;
}

# save_authuser(file, olduser, &details)
sub save_authuser
{
local($_, @htpasswd);
&open_readfile(HTPASSWD, $_[0]);
@htpasswd = <HTPASSWD>;
close(HTPASSWD);
&open_tempfile(HTPASSWD, ">$_[0]");
foreach (@htpasswd) {
	if (/^(\S+):(\S*)/ && $1 eq $_[1]) {
		&print_tempfile(HTPASSWD, $_[2]->{'user'},":",$_[2]->{'pass'},"\n");
		}
	else {
		&print_tempfile(HTPASSWD, $_);
		}
	}
&close_tempfile(HTPASSWD);
}

# create_authuser(file, &details)
# Add a new user to a file
sub create_authuser
{
&open_tempfile(HTPASSWD, ">> $_[0]");
&print_tempfile(HTPASSWD, $_[1]->{'user'},":",$_[1]->{'pass'},"\n");
&close_tempfile(HTPASSWD);
}

# delete_authuser(file, user)
# Delete some user from a file
sub delete_authuser
{
local($_, @htpasswd);
&open_readfile(HTPASSWD, $_[0]);
@htpasswd = <HTPASSWD>;
close(HTPASSWD);
&open_tempfile(HTPASSWD, "> $_[0]");
foreach (@htpasswd) {
	if (!/^(\S+):(\S*)/ || $1 ne $_[1]) {
		&print_tempfile(HTPASSWD, $_);
		}
	}
&close_tempfile(HTPASSWD);
}

###########################################################################
# Group Functions
###########################################################################

# list_authgroups(file)
# Returns an array of associative arrays containing information about
# groups from some text file
sub list_authgroups
{
local($_, @rv);
&open_readfile(HTGROUP, $_[0]);
while(<HTGROUP>) {
	if (/^(\S+):\s*(.*)/) {
		local($gr, @mems);
		$gr = $1; @mems = split(/\s+/, $2);
		push(@rv, { 'group' => $gr, 'members' => \@mems });
		}
	}
close(HTGROUP);
return @rv;
}

# get_authgroup(file, group)
sub get_authgroup
{
local(@tmp, $t);
@tmp = &list_authgroups($_[0]);
foreach $t (@tmp) {
	if ($t->{'group'} eq $_[1]) { return $t; }
	}
return undef;
}

# create_authgroup(file, &details)
sub create_authgroup
{
&open_tempfile(HTGROUP, ">> $_[0]");
&print_tempfile(HTGROUP, $_[1]->{'group'},": ",join(' ', @{$_[1]->{'members'}}),"\n");
&close_tempfile(HTGROUP);
}

# save_authgroup(file, oldgroup, &details)
sub save_authgroup
{
&open_readfile(HTGROUP, $_[0]);
@htgroup = <HTGROUP>;
close(HTGROUP);
&open_tempfile(HTGROUP, "> $_[0]");
foreach (@htgroup) {
	if (/^(\S+):\s*(.*)/ && $1 eq $_[1]) {
		&print_tempfile(HTGROUP, $_[2]->{'group'},": ",
			      join(' ', @{$_[2]->{'members'}}),"\n");
		}
	else {
		&print_tempfile(HTGROUP, $_);
		}
	}
&close_tempfile(HTGROUP);
}

# delete_authgroup(file, group)
sub delete_authgroup
{
&open_readfile(HTGROUP, $_[0]);
@htgroup = <HTGROUP>;
close(HTGROUP);
&open_tempfile(HTGROUP, "> $_[0]");
foreach (@htgroup) {
	if (!/^(\S+):\s*(.*)/ || $1 ne $_[1]) {
		&print_tempfile(HTGROUP, $_);
		}
	}
&close_tempfile(HTGROUP);
}

1;

