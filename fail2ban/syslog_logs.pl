# Contains a function to supply the syslog module with extra logs

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, %config);
require 'fail2ban-lib.pl';

# syslog_getlogs()
# Returns the Fail2Ban log
sub syslog_getlogs
{
my @rv;
my $conf = &get_config();
my ($def) = grep { $_->{'name'} eq 'Definition' } @$conf;
if ($def) {
	my $logtarget = &find_value("logtarget", $def);
	if ($logtarget && $logtarget =~ /^\//) {
		push(@rv, { 'file' => $logtarget,
			    'desc' => $text{'syslog_logtarget'},
			    'active' => 1 });
		}
	}
return @rv;
}

