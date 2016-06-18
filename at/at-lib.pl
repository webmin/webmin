# at-lib.pl
# Functions for listing and creating at jobs
use strict;
use warnings;
our (%text, %config); 
our $remote_user;

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();
our %access = &get_module_acl();

do "$config{'at_style'}-lib.pl";

# wrap_lines(text, width)
# Given a multi-line string, return an array of lines wrapped to
# the given width
sub wrap_lines
{
my @rv;
my $w = $_[1];
foreach my $rest (split(/\n/, $_[0])) {
	if ($rest =~ /\S/) {
		while(length($rest) > $w) {
			push(@rv, substr($rest, 0, $w));
			$rest = substr($rest, $w);
			}
		push(@rv, $rest);
		}
	else {
		# Empty line .. keep as it is
		push(@rv, $rest);
		}
	}
return @rv;
}

# can_edit_user(&access, user)
sub can_edit_user
{
my %umap;
map { $umap{$_}++; } split(/\s+/, $_[0]->{'users'});
if ($_[0]->{'mode'} == 1 && !$umap{$_[1]} ||
    $_[0]->{'mode'} == 2 && $umap{$_[1]}) { return 0; }
elsif ($_[0]->{'mode'} == 3) {
	return $remote_user eq $_[1];
	}
else {
	return 1;
	}
}

# list_allowed()
# Returns a list of all users in the cron allow file
sub list_allowed
{
local $_;
my @rv;
no strict "subs";
&open_readfile(ALLOW, $config{allow_file});
while(<ALLOW>) {
	next if (/^\s*#/);
	chop; push(@rv, $_) if (/\S/);
	}
close(ALLOW);
use strict "subs";
return @rv;
}


# list_denied()
# Return a list of users from the cron deny file
sub list_denied
{
local $_;
my @rv;
no strict "subs";
&open_readfile(DENY, $config{deny_file});
while(<DENY>) {
	next if (/^\s*#/);
	chop; push(@rv, $_) if (/\S/);
	}
close(DENY);
use strict "subs";
return @rv;
}


# save_allowed(user, user, ...)
# Save the list of allowed users
sub save_allowed
{
&lock_file($config{allow_file});
if (@_) {
	local($_);
	no strict "subs";
	&open_tempfile(ALLOW, ">$config{allow_file}");
	foreach my $u (@_) {
		&print_tempfile(ALLOW, $u,"\n");
		}
	&close_tempfile(ALLOW);
	use strict "subs";
	chmod(0444, $config{allow_file});
	}
else {
	&unlink_file($config{allow_file});
	}
&unlock_file($config{allow_file});
}


# save_denied(user, user, ...)
# Save the list of denied users
sub save_denied
{
&lock_file($config{deny_file});
if (@_ || !-r $config{'allow_file'}) {
	no strict "subs";
	&open_tempfile(DENY, ">$config{deny_file}");
	foreach my $u (@_) {
		&print_tempfile(DENY, $u,"\n");
		}
	&close_tempfile(DENY);
	use strict "subs";
	chmod(0444, $config{deny_file});
	}
else {
	&unlink_file($config{deny_file});
	}
&unlock_file($config{deny_file});
}

# can_use_at(user)
# Returns 1 if some user is allowed to use At jobs, based on the allow
# any deny files.
sub can_use_at
{
my ($user) = @_;
my (@allow, @deny, @denied);
if (!$config{'allow_file'}) {
	return 1;	# not supported by OS
	}
elsif (@allow = &list_allowed()) {
	return &indexof($user, @allow) >= 0;	# check allowed list
	}
elsif (@deny = &list_denied()) {
	return &indexof($user, @denied) < 0;	# check denied list
	}
else {
	return 1;	# if neither exists, fall back to allowing all
	}
}

1;

