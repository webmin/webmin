#!/usr/local/bin/perl
# save_opts.cgi
# Save various sendmail options

require './sendmail-lib.pl';
&ReadParse();
$access{'opts'} || &error($text{'opts_ecannot'});
&error_setup($text{'opts_err'});
&lock_file($config{'sendmail_cf'});
$conf = &get_sendmailcf();
$ver = &check_sendmail_version($conf);

# Save directives
&save_doption("S", "DS", 1);
&save_doption("R", "DR", 1);
&save_doption("H", "DH", 1);

# Save other options
&save_option("QueueLA", '[\d\.]+', $text{'opts_queuela'});
&save_option("RefuseLA", '[\d\.]+', $text{'opts_refusela'});
&save_option("MaxDaemonChildren", '\d+', $text{'opts_maxch'});
&save_option("ConnectionRateThrottle", '\d+', $text{'opts_throttle'});
&save_option("MinQueueAge", '\d+\S', $text{'opts_minqueueage'});
&save_option("MaxQueueRunSize", '\d+', $text{'opts_runsize'});
&save_option("Timeout.queuereturn", '\d+[dmhwsy]', $text{'opts_queuereturn'});
&save_option("Timeout.queuewarn", '\d+[dmhwsy]', $text{'opts_queuewarn'});
&save_option("QueueDirectory", '\/\S+', $text{'opts_queue'});
&save_option("PostMasterCopy", '\S+', $text{'opts_postmaster'});
&save_option("ForwardPath", '\S+', $text{'opts_forward'});
&save_option("MinFreeBlocks", '\d+', $text{'opts_minfree'});
&save_option("MaxMessageSize", '\d+', $text{'opts_maxmessage'});
&save_option("LogLevel", '\d+', $text{'opts_loglevel'});
$in{'DontBlameSendmail'} =~ s/\0/ /g;
&save_option("DontBlameSendmail", '.*\S.*', $text{'opts_blame'});
&save_option("SendMimeErrors", '.*');
$in{'DeliveryMode_def'} = 1 if (!$in{'DeliveryMode'});
&save_option("DeliveryMode", '.*');
$in{'QueueSortOrder_def'} = 1 if (!$in{'QueueSortOrder'});
&save_option("QueueSortOrder", '.*');
&save_option("MaxHopCount", '\d+', $text{'opts_hops'});
&save_option("MatchGECOS", '.*');
if ($ver >= 10) {
	&save_option("MaxRecipientsPerMessage", '\d+', $text{'opts_maxrcpt'});
	&save_option("BadRcptThrottle", '\d+', $text{'opts_maxbad'});
	}
&flush_file_lines();
&unlock_file($config{'sendmail_cf'});
&restart_sendmail();
&webmin_log("opts", undef, undef, \%in);
&redirect("");

# save_doption(type2, input, blank)
sub save_doption
{
local ($oldstr, $old) = &find_type2("D", $_[0], $conf);
@oldlist = $oldstr ? ( $oldstr ) : ( );
if ($in{"$_[1]_def"}) {
	@newlist = $_[2] && $oldstr ?
			( { 'type' => 'D', 'values' => [ $_[0] ] } ) : ( );
	}
elsif ($in{$_[1]} !~ /^\S+$/) {
	&error(&text('opts_ehost', $in{$_[1]}));
	}
else {
	@newlist = ( { 'type' => 'D', 'values' => [ $_[0].$in{$_[1]} ] } );
	}
&save_directives($conf, \@oldlist, \@newlist);
}

# save_option(name, regexp, what)
sub save_option
{
local ($oldstr, $old) = &find_option($_[0], $conf);
local @oldlist = $oldstr ? ( $oldstr ) : ( );
local (@newlist, $re); $re = $_[1];
if ($in{"$_[0]_def"}) { @newlist = (); }
elsif ($in{$_[0]} !~ /^$re$/) {
	&error(&text('opts_einvalid', $in{$_[0]}, $_[2]));
	}
else { @newlist = ( { 'type' => 'O', 'values' => [ " $_[0]=$in{$_[0]}" ] } ); }
&save_directives($conf, \@oldlist, \@newlist);
}

# save_options(name, regexp, what)
sub save_options
{
local @oldlist = map { $_->[0] } &find_options($_[0], $conf);
local @newlist;
if (!$in{"$_[0]_def"}) {
	local $re = $_[1];
	foreach my $v (split(/\r?\n/, $in{$_[0]})) {
		$v =~ /^$re$/ ||
			&error(&text('opts_einvalid', $in{$_[0]}, $_[2]));
		push(@newlist, { 'type' => 'O', 'values' => [ " $_[0]=$v" ] });
		}
	}
&save_directives($conf, \@oldlist, \@newlist);
}

