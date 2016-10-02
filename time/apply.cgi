#!/usr/local/bin/perl

local $format;
local $out;

require "./time-lib.pl";
use Time::Local;

&ReadParse();

if (!$in{'action'}) {
	# user probably hit return in the time server field
	$in{'action'} = $text{'index_sync'};
	}
$mode = "time";

if ($in{'action'} eq $text{'action_sync'}) {
  # Set system time to hardware time
  &error( $text{ 'acl_nosys' } ) if( $access{ 'sysdate' } );
  local $flags = &get_hwclock_flags();
  $out = &backquote_logged("hwclock $flags --hctosys");
  &error( &text( 'error_sync', $out ) ) if( $out ne "" );
  &webmin_log("sync");

} elsif ($in{'action'} eq $text{'action_sync_s'}) {
  # Set hardware time to system time
  &error( $text{ 'acl_nohw' } ) if( $access{ 'hwdate' } && $access{'sysdate'} );
  local $flags = &get_hwclock_flags();
  $out = &backquote_logged("hwclock $flags --systohc");
  &error( &text( 'error_sync', $out ) ) if( $out ne "" );
  &webmin_log("sync_s");

} elsif($in{'action'} eq $text{'action_apply'} || $in{'mode'} eq 'sysdate' ) {
  # Setting the system time
  &error( $text{ 'acl_nosys' } ) if( $access{ 'sysdate' } );
  $err = &set_system_time($in{ 'second' }, $in{'minute'}, $in{'hour'},
		   $in{'date'}, $in{'month'}-1, $in{'year'}-1900);
  &error($err) if ($err);
  &webmin_log("set", "date", time(), \%in);

} elsif ($in{'action'} eq $text{'action_save'} || $in{'mode'} eq 'hwdate' ) {
  # Setting the hardware time
  &error( $text{ 'acl_nohw' } ) if( $access{ 'hwdate' } );
  $err = &set_hardware_time($in{ 'second' }, $in{'minute'}, $in{'hour'},
		   $in{'date'}, $in{'month'}-1, $in{'year'}-1900);
  &error( &text( 'error_hw', $err ) ) if ($err);
  local $hwtime = timelocal($in{'second'}, $in{'minute'}, $in{'hour'},
			    $in{'date'}, $in{'month'}-1, $in{'year'} < 200 ?
			    $in{'year'} : $in{'year'}-1900);
  &webmin_log("set", "hwclock", $hwtime, \%in);

} elsif ($in{'action'} eq $text{'index_sync'} || $in{'mode'} eq 'ntp') {
  # Sync with a time server
  $access{'ntp'} || &error($text{'acl_nontp'});
  $in{'timeserver'} =~ /\S/ || &error($text{'error_etimeserver'});
  $err = &sync_time($in{'timeserver'}, $in{'hardware'});
  &error($err) if ($err);

  # Save settings in module config
  &lock_file($module_config_file);
  $config{'timeserver'} = $in{'timeserver'};
  $config{'timeserver_hardware'} = $in{'hardware'};
  &save_module_config();
  &unlock_file($module_config_file);

  # Create, update or delete the syncing cron job
  $job = &find_webmin_cron_job();
  if ($in{'sched'} || $in{'boot'}) {
	$job ||= { 'module' => $module_name,
		   'func' => 'sync_time_cron' };
	$job->{'disabled'} = $in{'sched'} ? 0 : 1;
	$job->{'boot'} = $in{'boot'};
	&webmincron::parse_times_input($job, \%in);
	&webmincron::create_webmin_cron($job);
	}
  elsif ($job) {
	&webmincron::delete_webmin_cron($job);
	}

  &webmin_log("remote", $in{'action'} eq $text{'action_timeserver_sys'} ?  "date" : "hwclock", $rawtime, \%in);
  $mode = "sync";
}

&redirect("index.cgi?mode=$mode");

