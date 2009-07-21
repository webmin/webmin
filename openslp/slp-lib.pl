# An OpenSLP webmin module
# by Monty Charlton <monty@caldera.com>,
#
# Copyright (c) 2000 Caldera Systems
#
# Permission to use, copy, modify, and distribute this software and its
# documentation under the terms of the GNU General Public License is hereby 
# granted. No representations are made about the suitability of this software 
# for any purpose. It is provided "as is" without express or implied warranty.
# See the GNU General Public License for more details.
#

BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

#$config_file = "./config-$gconfig{'os_type'}";
$config_file = "$module_config_directory/config";
$config = &parse_config_file;

# get_snda_config()
sub get_snda_config
{
local $snda;
flock SLP, 1 || &error("$text->{'error_flock_on'} $config->{'slpd_conf'}: $!\n");
open(SLP, $config->{'slpd_conf'}) || &error("$text->{'error_open'} $config->{'slpd_conf'}: $!\n");
while(<SLP>) {
	s/\r|\n//g;
	if (/^(\s|#|;)*net.slp.useScopes\s*=\s*(.*)/) {
		push(@{$snda->{'useScopes'}}, split(/\s*,\s*/, $2));
		$snda->{'useScopesDisabled'}++ if ($1 =~ /;|#/);
		}
	elsif (/^(\s|#|;)*net.slp.DAAddresses\s*=\s*(.*)/) {
		push(@{$snda->{'DAAddresses'}}, split(/\s*,\s*/, $2));
		$snda->{'DAAddressesDisabled'}++ if ($1 =~ /;|#/);
		}
	}
close(SLP);
flock SLP, 8 || &error("$text->{'error_flock_off'} $config->{'slpd_conf'}: $!\n");
return $snda;
}

# get_netcfg_config()
sub get_netcfg_config
{
local $netcfg;
flock SLP, 1 || &error("$text->{'error_flock_on'} $config->{'slpd_conf'}: $!\n");
open(SLP, $config->{'slpd_conf'}) || &error("$text->{'error_open'} $config->{'slpd_conf'}: $!\n");
while(<SLP>) {
        s/\r|\n//g;
        if (/^(\s|#|;)*net.slp.isBroadcastOnly\s*=\s*(\S+)/) {
                $netcfg->{'isBroadcastOnly'} = $2;
                $netcfg->{'isBroadcastOnlyDisabled'}++ if ($1 =~ /;|#/);
                }
        elsif (/^(\s|#|;)*net.slp.passiveDADetection\s*=\s*(\S+)/) {
                $netcfg->{'passiveDADetection'} = $2;
                $netcfg->{'passiveDADetectionDisabled'}++ if ($1 =~ /;|#/);
                }
        elsif (/^(\s|#|;)*net.slp.activeDADetection\s*=\s*(\S+)/) {
                $netcfg->{'activeDADetection'} = $2;
                $netcfg->{'activeDADetectionDisabled'}++ if ($1 =~ /;|#/);
                }
	elsif (/^(\s|#|;)*net.slp.DAActiveDiscoveryInterval\s*=\s*(\S+)/) {
		$netcfg->{'DAActiveDiscoveryInterval'} = $2;
		$netcfg->{'DAActiveDiscoveryIntervalDisabled'}++ if ($1 =~ /;|#/);
		}
	elsif (/^(\s|#|;)*net.slp.multicastTTL\s*=\s*(\S+)/) {
                $netcfg->{'multicastTTL'} = $2;
                $netcfg->{'multicastTTLDisabled'}++ if ($1 =~ /;|#/);
                }
	elsif (/^(\s|#|;)*net.slp.DADiscoveryMaximumWait\s*=\s*(\S+)/) {
                $netcfg->{'DADiscoveryMaximumWait'} = $2;
                $netcfg->{'DADiscoveryMaximumWaitDisabled'}++ if ($1 =~ /;|#/);
                }
	elsif (/^(\s|#|;)*net.slp.DADiscoveryTimeouts\s*=\s*(.*)/) {
                push(@{$netcfg->{'DADiscoveryTimeouts'}}, split(/\s*,\s*/, $2));
                $netcfg->{'DADiscoveryTimeoutsDisabled'}++ if ($1 =~ /;|#/);
                }
	elsif (/^(\s|#|;)*net.slp.HintsFile\s*=\s*(\S+)/) {
                $netcfg->{'HintsFile'} = $2;
                $netcfg->{'HintsFileDisabled'}++ if ($1 =~ /;|#/);
                }
	elsif (/^(\s|#|;)*net.slp.multicastMaximumWait\s*=\s*(\S+)/) {
                $netcfg->{'multicastMaximumWait'} = $2;
                $netcfg->{'multicastMaximumWaitDisabled'}++ if ($1 =~ /;|#/);
                }
	elsif (/^(\s|#|;)*net.slp.multicastTimeouts\s*=\s*(.*)/) {
                push(@{$netcfg->{'multicastTimeouts'}}, split(/\s*,\s*/, $2));
                $netcfg->{'multicastTimeoutsDisabled'}++ if ($1 =~ /;|#/);
                }
	elsif (/^(\s|#|;)*net.slp.unicastMaximumWait\s*=\s*(\S+)/) {
                $netcfg->{'unicastMaximumWait'} = $2;
                $netcfg->{'unicastMaximumWaitDisabled'}++ if ($1 =~ /;|#/);
                }
	elsif (/^(\s|#|;)*net.slp.randomWaitBound\s*=\s*(\S+)/) {
                $netcfg->{'randomWaitBound'} = $2;
                $netcfg->{'randomWaitBoundDisabled'}++ if ($1 =~ /;|#/);
                }
	elsif (/^(\s|#|;)*net.slp.MTU\s*=\s*(\S+)/) {
                $netcfg->{'MTU'} = $2;
                $netcfg->{'MTUDisabled'}++ if ($1 =~ /;|#/);
                }
	elsif (/^(\s|#|;)*net\.slp\.interfaces\s*=\s*(.*)/) {
                push(@{$netcfg->{'interfaces'}}, split(/\s*,\s*/, $2));
                $netcfg->{'interfacesDisabled'}++ if ($1 =~ /;|#/);
                }
        }
close(SLP);
flock SLP, 8 || &error("$text->{'error_flock_off'} $config->{'slpd_conf'}: $!\n");
return $netcfg;
} 

# get_dacfg_config()
sub get_dacfg_config
{
local $dacfg;
flock SLP, 1 || &error("$text->{'error_flock_on'} $config->{'slpd_conf'}: $!\n");
open(SLP, $config->{'slpd_conf'}) || &error("$text->{'error_open'} $config->{'slpd_conf'}: $!\n");
while(<SLP>) {
	s/\r|\n//g;
	if (/^(\s|#|;)*net.slp.isDA\s*=\s*(\S+)/) {
		$dacfg->{'isDA'} = $2;
		$dacfg->{'isDADisabled'}++ if ($1 =~ /;|#/);
		}
	}
close(SLP);
flock SLP, 8 || &error("$text->{'error_flock_off'} $config->{'slpd_conf'}: $!\n");
return $dacfg;
}

# get_log_config()
sub get_log_config
{
local $log;
flock SLP, 1 || &error("$text->{'error_flock_on'} $config->{'slpd_conf'}: $!\n");
open(SLP, $config->{'slpd_conf'}) || &error("$text->{'error_open'} $config->{'slpd_conf'}: $!\n");
while(<SLP>) {
	s/\r|\n//g;
	if (/^(\s|#|;)*net.slp.traceDATraffic\s*=\s*(\S+)/) {
		$dacfg->{'traceDATraffic'} = $2;
		$dacfg->{'traceDATrafficDisabled'}++ if ($1 =~ /;|#/);
		}
	elsif (/^(\s|#|;)*net.slp.traceMsg\s*=\s*(\S+)/) {
		$dacfg->{'traceMsg'} = $2;
		$dacfg->{'traceMsgDisabled'}++ if ($1 =~ /;|#/);
		}
	elsif (/^(\s|#|;)*net.slp.traceDrop\s*=\s*(\S+)/) {
		$dacfg->{'traceDrop'} = $2;
		$dacfg->{'traceDropDisabled'}++ if ($1 =~ /;|#/);
		}
	elsif (/^(\s|#|;)*net.slp.traceReg\s*=\s*(\S+)/) {
		$dacfg->{'traceReg'} = $2;
		$dacfg->{'traceRegDisabled'}++ if ($1 =~ /;|#/);
		}

	}
close(SLP);
flock SLP, 8 || &error("$text->{'error_flock_off'} $config->{'slpd_conf'}: $!\n");
return $dacfg;
}

# enable_list_line(&list, &line)
sub enable_list_line
{
flock SLP, 1 || &error("$text->{'error_flock_on'} $config->{'slpd_conf'}: $!\n");
open(SLP, $config->{'slpd_conf'}) || &error("$text->{'error_open'} $config->{'slpd_conf'}: $!\n");
local @slp = <SLP>;
close(SLP);
flock SLP, 8 || &error("$text->{'error_flock_off'} $config->{'slpd_conf'}: $!\n");
flock SLP, 2 || &error("$text->{'error_flock_on'} $config->{'slpd_conf'}: $!\n");
&open_tempfile(SLP, ">$config->{'slpd_conf'}") || &error("$text->{'error_open'} $config->{'slpd_conf'}: $!\n");
local $line = pop;
local $list = join ",", @_;
foreach(@slp) {
	if (/^(\s|#|;)*net.slp.$line\s*=\s*\S+/ && $list) {
		&print_tempfile(SLP, "net.slp.$line=$list\n");
		}
	else {
		&print_tempfile(SLP, $_);
		}
	}
&close_tempfile(SLP);
flock SLP, 8 || &error("$text->{'error_flock_off'} $config->{'slpd_conf'}: $!\n");
}

# enable_single_val_line(&val, &line)
sub enable_single_val_line
{
open(SLP, $config->{slpd_conf}) || &error("$text->{'error_open'} $config->{'slpd_conf'}: $!\n");
flock SLP, 1 || &error("$text->{'error_flock_on'} $config->{'slpd_conf'}: $!\n");
local @slp = <SLP>;
close(SLP);
flock SLP, 8 || &error("$text->{'error_flock_off'} $config->{'slpd_conf'}: $!\n");
flock SLP, 2 || &error("$text->{'error_flock_on'} $config->{'slpd_conf'}: $!\n");
&open_tempfile(SLP, ">$config->{'slpd_conf'}") || &error("$text->{'error_open'} $config->{'slpd_conf'}: $!\n");
local $line = pop;
foreach(@slp) {
	if (/^(\s|#|;)*net.slp.$line\s*=\s*\S+\s*$/) {
		&print_tempfile(SLP, "net.slp.$line=@_[0]\n");
		}
	else {
		&print_tempfile(SLP, $_);
		}
	}
&close_tempfile(SLP);
flock SLP, 8 || &error("$text->{'error_flock_off'} $config->{'slpd_conf'}: $!\n");
}

# disable_line(line)
sub disable_line
{
flock SLP, 1 || &error("$text->{'error_flock_on'} $config->{'slpd_conf'}: $!\n");
open(SLP, $config->{'slpd_conf'}) || &error("$text->{'error_open'} $config->{'slpd_conf'}: $!\n");
local @slp = <SLP>;
close(SLP);
flock SLP, 8 || &error("$text->{'error_flock_off'} $config->{'slpd_conf'}: $!\n");
flock SLP, 2 || &error("$text->{'error_flock_on'} $config->{'slpd_conf'}: $!\n");
&open_tempfile(SLP, ">$config->{'slpd_conf'}") || &error("$text->{'error_open'} $config->{'slpd_conf'}: $!\n");
foreach(@slp) {
	if (/^(\s|#|;)*net.slp.@_[0]\s*=\s*(\S+)/) {
		&print_tempfile(SLP, ";net.slp.@_[0]=$2\n");
		}
	else {
		&print_tempfile(SLP, $_);
		}
	}
&close_tempfile(SLP);
flock SLP, 8 || &error("$text->{'error_flock_off'} $config->{'slpd_conf'}: $!\n");
}

# parse_config_file
sub parse_config_file
{ 
local %dummy;
flock FH, 1 || &error("$text->{'error_flock_on'} $config_file: $!\n");
open(FH, $config_file) || &error("$text->{'error_open'} $config_file: $!\n");
while (<FH>) {
  $dummy{$1} = $2 if (/(\S+)=(.+)/)
}
return \%dummy;
close(FH);
flock FH, 8 || &error("$text->{'error_flock_off'} $config_file: $!\n");
}

# restart
sub restart
{
local $pid;
flock PID, 1 || &error("$text->{'error_flock_on'} $config->{'slpd_pid'}: $!\n");
open(PID, $config->{'slpd_pid'}) || &start_slpd;
while (<PID>) {
  $pid=$1, last if (/(\d+)/)
}
close(PID);
flock PID, 8 || &error("$text->{'error_flock_off'} $config->{'slpd_pid'}: $!\n");
if ($pid =~ /\d+/) {
  kill('HUP', $pid) || &error("$text->{'error_hup'}: $config->{'slpd_pid'}\n");
} else {
  &start_slpd;
}
}

# is slpd running?
sub slpd_is_running
{
local $pid;
flock PID, 1 || &error("$text->{'error_flock_on'} $config->{'slpd_pid'}: $!\n");
open(PID, $config->{'slpd_pid'}) || return 0;
while (<PID>) {
  $pid=$1, last if (/(\d+)/)
}
close(PID);
flock PID, 8 || &error("$text->{'error_flock_off'} $config->{'slpd_pid'}: $!\n");
if ($pid =~ /\d+/) {
  # the pid file has a number in it but 
  # we need to check if slpd is _actually_ running
  if (kill 0 => $pid) {
    return $pid;
  } else {
    &stop_slpd;
    return 0;
  }
} else {
  return 0;
}
}

sub start_slpd
{
&error_setup($text->{'start_err'});
local $temp = &transname();
local $rv = &system_logged("($config->{'start_cmd'}) >$temp 2>&1");
local $out = `cat $temp`;
unlink($temp);
sleep(2);
&webmin_log("start");
}

sub stop_slpd
{
$out = &backquote_logged("$config->{'stop_cmd'} 2>&1");
&error_setup($text->{'stop_err'});
if ($?) {
  &error("<pre>$?\n$out</pre>");
}
&webmin_log("stop");
}

1;

