#!/usr/local/bin/perl

require "./time-lib.pl";

local ($rawdate, $rawhwdate, %system_date, $rawtime, %hw_date, $txt);
$txt = "";

&error( $text{ 'acl_error' } ) if( $access{ 'sysdate' } && $access{ 'hwdate' } );

if (!$access{'sysdate'} && !$access{'hwdate'} && $config{'hwtime'}) {
	$arr = "0,1";
	}
else {
	$arr = "0";
	}
&ui_print_header(undef,  $text{ 'index_title' }, "", "index", 1, 1, undef,
	&help_search_link("date hwclock", "man"),
	qq(<script src="time.js"></script>\n),
	qq(onLoad="F=[$arr];timeInit(F); setTimeout('timeUpdate(F)', 5000);"));

if (!$access{'sysdate'} && !&has_command("date")) {
	print &text( 'error_cnf', "<tt>date</tt>"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}
if (!$access{'hwdate'} && $config{'hwtime'} && !&has_command("hwclock")) {
	print &text( 'error_cnf', "<tt>hwclock</tt>"),"<p>\n";
	&ui_print_footer("/", $text{'index'});
	exit;
	}

# Get the system time
@tm = &get_system_time();
$system_date{ 'second' } = $tm[0];
$system_date{ 'minute' } = $tm[1];
$system_date{ 'hour' } = $tm[2];
$system_date{ 'date' } = $tm[3];
$system_date{ 'month' } = &number_to_month($tm[4]);
$system_date{ 'year' } = $tm[5]+1900;
$system_date{ 'day' } = &number_to_weekday($tm[6]);

if( !$access{'sysdate'} )
{
  # Show system time for editing
  print( 
"<form action=apply.cgi>",
  &tabletime( &hlink( $text{ 'sys_title' }, "system_time" ), 0, %system_date ),
  "<input type=submit name=action value=\"", $text{ 'action_apply' }, "\">",
  $config{'hwtime'} ? " <input type=submit name=action value=\"$text{'action_sync'}\">\n" : "");
print "</form><p>";
}
else
{
   # Just show current time
   print &tabletime( &hlink( $text{ 'sys_title' }, "system_time" ), 1, %system_date ),"<p>\n";
}

# Get the hardware time
if ($config{'hwtime'}) {
	local @tm = &get_hardware_time();
	@tm || &error($get_hardware_time_error || $text{'index_eformat'});
	$hw_date{ 'second' } = $tm[0];
	$hw_date{ 'minute' } = $tm[1];
	$hw_date{ 'hour' } = $tm[2];
	$hw_date{ 'date' } = $tm[3];
	$hw_date{ 'month' } = &number_to_month($tm[4]);
	$hw_date{ 'year'} = $tm[5]+1900;
	$hw_date{ 'day' } = &number_to_weekday($tm[6]);

	if(!$access{'hwdate'}) {
		# Allow editing of hardware time
		if( !$access{ 'sysdate' } ) {
		    $hw_date{ 'second' } = $system_date{ 'second' } if( $hw_date{ 'second' } - $system_date{ 'second' } <= $config{ 'lease' } );
			}
	    
		print( 
		"<p><form action=apply.cgi>",
		  &tabletime( &hlink( $text{ 'hw_title' }, "hardware_time" ), 0, %hw_date ),
		  "<input type=submit name=action value=\"", $text{ 'action_save' }, "\">",
		  $config{'hwtime'} ? " <input type=submit name=action value=\"".$text{ 'action_sync_s' }."\">" : "", "</form><p>" );
		}
	else {
		# Show show the hardware time
		print "<p>",&tabletime( &hlink( $text{ 'hw_title' }, "hardware_time" ), 1, %hw_date ),"<p>\n";
		}
	}

if ($access{'timezone'} && &has_timezone()) {
	print "<form action=save_timezone.cgi>\n";
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'index_tzheader'}</b></td> </tr>\n";
	print "<tr $cb> <td><table>\n";

	@zones = &list_timezones();
	$cz = &get_current_timezone();
	$found = 0;
	print "<tr> <td><b>$text{'index_tz'}</b></td>\n";
	print "<td><select name=zone>\n";
	foreach $z (@zones) {
		if ($z->[0] =~ /^(.*)\/(.*)$/) {
			$pfx = $1;
			}
		else {
			$pfx = undef;
			}
		if ($pfx ne $lastpfx && $z ne $zones[0]) {
			print "<option value=''>----------\n";
			}
		$lastpfx = $pfx;
		printf "<option value=%s %s>%s\n",
			$z->[0], $cz eq $z->[0] ? "selected" : "",
			$z->[1] ? "$z->[0] ($z->[1])" : $z->[0];
		$found = 1 if ($cz eq $z->[0]);
		}
	if (!$found && $cz) {
		printf "<option value=%s %s>%s\n",
			$cz, "selected", $cz;
		}
	print "</select></td> </tr>\n";

	print "</table></td></tr></table>\n";
	print "<input type=submit value='$text{'save'}'></form>\n";
	}

if( ( !$access{ 'sysdate' } && &has_command( "date" ) || !$access{ 'hwdate' } && &has_command( "hwclock" ) ) && $access{'ntp'} )
{
	# Show time server input
	print(
	"<p><form action=apply.cgi>",
	  "<table nosave border width=\"100%\">",
		"<tr $tb>",
		  "<td colspan=2><b>", &hlink( $text{ 'index_timeserver' }, "timeserver" ), "</b></td>",
		"</tr>",
		"<tr $cb><td><table width=100%>",
		  "<td><b>",$text{ 'index_addresses' }, "</b></td>",
		  "<td>",&p_entry( "timeserver", $config{'timeserver'}, 40 ),
		  "</td> </tr>\n");

	# Show hardware time checkbox
	if ($config{'hwtime'}) {
		print "<tr $cb> <td></td> <td>\n";
		printf "<input type=checkbox name=hardware value=1 %s> %s\n",
			$config{'timeserver_hardware'} ? "checked" : "",
			$text{'index_hardware2'};
		print "</td> </tr>\n";
		}

	# Show schedule input
	&foreign_require("cron", "cron-lib.pl");
	$job = &find_cron_job();
	print "<tr $cb> <td><b>$text{'index_sched'}</b></td>\n";
	printf "<td><input type=radio name=sched value=0 %s> %s\n",
		$job ? "" : "checked", $text{'no'};
	printf "<input type=radio name=sched value=1 %s> %s</td> </tr>\n",
		$job ? "checked" : "", $text{'index_schedyes'};

	print "<tr $cb> <td colspan=2><table border width=100%>\n";
	$job ||= { 'mins' => '0',
		   'hours' => '0',
		   'days' => '*',
		   'months' => '*',
		   'weekdays' => '*' };
	&cron::show_times_input($job);
	print "</table></td> </tr>\n";

	print "</table></td></tr></table>\n";
	print "<input type=submit name=action value='$text{'index_sync'}'></form>";
}


&ui_print_footer( "/", $text{ 'index' } );

# tabletime(label, read-only, &time)
sub tabletime
{
  my ( $label, $ro, %src ) = @_,
  %assoc_day = ( "Mon", $text{ 'day_1' }, "Tue", $text{ 'day_2' }, "Wed", $text{ 'day_3' }, "Thu", $text{ 'day_4' }, "Fri", $text{ 'day_5' }, "Sat", $text{ 'day_6' }, "Sun", $text{ 'day_0' } ),
  %assoc_month = ( "Jan", $text{ 'month_1' }, "Feb", $text{ 'month_2' }, "Mar", $text{ 'month_3' }, "Apr", $text{ 'month_4' }, "May", $text{ 'month_5' }, "Jun", $text{ 'month_6' }, "Jul", $text{ 'month_7' }, "Aug", $text{ 'month_8' }, "Sep", $text{ 'month_9' }, "Oct", $text{ 'month_10' }, "Nov", $text{ 'month_11' }, "Dec", $text{ 'month_12' } );

$rv =
"<table nosave border width=\"100%\"><tr ". $tb. "><td>". $label. "</td></tr></table>\n".
"<table nosave border width=\"100%\">".
  "<tr ". $cb. ">".
	"<td nosave><b>". $text{ 'day' }. "</b></td>\n".
	"<td nosave><b>". $text{ 'date' }. "</b></td>\n".
	"<td nosave><b>". $text{ 'month' }. "</b></td>\n".
	"<td nosave><b>". $text{ 'year' }. "</b></td>\n".
	"<td><b>". $text{ 'hour' }. "</b></td>\n".
  "</tr>\n";
if (!$ro) {
	$rv .= "<tr ". $cb. ">".
		"<td>". ($assoc_day{ $src{ 'day' } } || $src{'day'})."</td>\n".
		"<td>". &p_select( "date", $src{ 'date' }, ( 1..31 ) ). "</td>\n".
		"<td>". &p_select_wdl( "month", $assoc_month{ $src{ 'month' } }, "01",( $text{ 'month_1' }, "02", $text{ 'month_2' }, "03", $text{ 'month_3' }, "04", $text{ 'month_4' }, "05", $text{ 'month_5' }, "06", $text{ 'month_6' }, "07", $text{ 'month_7' }, "08", $text{ 'month_8' }, "09", $text{ 'month_9' }, "10", $text{ 'month_10' }, "11", $text{ 'month_11' }, "12", $text{ 'month_12' } ) ). "</td>\n".
		"<td>". &p_select( "year", $src{ 'year' }, ( 1969..2037 ) ). "</td>\n".
		"<td>". &p_select( "hour", &zeropad($src{ 'hour' }, 2), ( "00", "01", "02", "03", "04", "05", "06", "07", "08", "09", 10..23 ) ). "\n:". &p_select( "minute", &zeropad($src{ 'minute' }, 2), ( "00", "01", "02", "03", "04", "05", "06", "07", "08", "09", 10..59) ). ":". &p_select( "second", &zeropad($src{ 'second' }, 2), ( "00", "01", "02", "03", "04", "05", "06", "07", "08", "09", 10..59 ) ). "</td>\n".
	  "</tr>\n".
	"</table>";
	}
else {
	$rv .= "<tr $cb>".
	       "<td>".($assoc_day{ $src{ 'day' } } || $src{'day'})."</td>\n".
	       "<td>".$src{'date'}."</td>\n".
	       "<td>".$src{'month'}."</td>\n".
	       "<td>".$src{'year'}."</td>\n".
	       "<td>".$src{'hour'}.":".$src{'minute'}.":".$src{'second'}."</td>\n".
               "</tr></table>\n";
	}
return $rv;
}
