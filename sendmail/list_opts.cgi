#!/usr/local/bin/perl
# list_opts.cgi
# A form for editing options set with the 'O foo=bar' directive,
# and other things.

require './sendmail-lib.pl';
$access{'opts'} || &error($text{'opts_ecannot'});
&ui_print_header(undef, $text{'opts_title'}, "");

# Get config and start form
$conf = &get_sendmailcf();
$ver = &check_sendmail_version($conf);
$default = $text{'opts_default'};
print &ui_form_start("save_opts.cgi", "post");
print &ui_table_start($text{'opts_title'}, "width=100%", 4);

# Smart host for outgoing mail
($dsstr, $ds) = &find_type2("D", "S", $conf);
print &ui_table_row(&hlink($text{'opts_ds'}, "opt_DS"),
	&ui_opt_textbox("DS", $ds, 40, $text{'opts_direct'}), 3);

# Host for unqualified names
($drstr, $dr) = &find_type2("D", "R", $conf);
print &ui_table_row(&hlink($text{'opts_dr'}, "opt_DR"),
	&ui_opt_textbox("DR", $dr, 40, $text{'opts_local'}), 3);

# Host for local users
($dhstr, $dh) = &find_type2("D", "H", $conf);
print &ui_table_row(&hlink($text{'opts_dh'}, "opt_DH"),
	&ui_opt_textbox("DH", $dh, 40, $text{'opts_local'}), 3);

# Queuing / delivery mode
($dmstr, $dm) = &find_option("DeliveryMode", $conf);
@dmodes = ('background', 'queue-only', 'interactive', 'deferred');
if ($dm) {
	($dmode) = grep { substr($_, 0, 1) eq substr($dm, 0, 1) } @dmodes;
	}
print &ui_table_row(&hlink($text{'opts_dmode'}, "opt_dmode"),
	&ui_radio("DeliveryMode", $dmode,
		  [ [ '', $text{'default'} ],
		    map { [ $_, $text{"opts_".$_} ] } @dmodes ]), 3);

# Sort mail queue by
($qsostr, $qso) = &find_option("QueueSortOrder", $conf);
@qsmodes = ('priority', 'host', 'time');
if ($qso) {
	($qsorder) = grep { substr($_, 0, 1) eq substr($qso, 0, 1) } @qsmodes;
	}
print &ui_table_row(&hlink($text{'opts_qso'}, "opt_qso"),
	&ui_radio("QueueSortOrder", $qsorder,
		  [ [ '', $text{'default'} ],
		    map { [ $_, $text{"opts_".$_} ] } @qsmodes ]), 3);

&option_input($text{'opts_queuela'}, "QueueLA", $conf, $default, 6);
&option_input($text{'opts_refusela'}, "RefuseLA", $conf, $default,6);

&option_input($text{'opts_maxch'}, "MaxDaemonChildren",
	      $conf, $default, 6);
&option_input($text{'opts_throttle'}, "ConnectionRateThrottle",
	      $conf, $default, 6);

&option_input($text{'opts_minqueueage'}, "MinQueueAge",
	      $conf, $default, 6);
&option_input($text{'opts_runsize'}, "MaxQueueRunSize", $conf, $default, 8);

&option_input($text{'opts_queuereturn'}, "Timeout.queuereturn",
	      $conf, $default, 6);
&option_input($text{'opts_queuewarn'}, "Timeout.queuewarn",
	      $conf, $default, 6);

&option_input($text{'opts_queue'}, "QueueDirectory", $conf, $default, 35);

&option_input($text{'opts_postmaster'}, "PostMasterCopy",
	      $conf, "Postmaster", 35);

&option_input($text{'opts_forward'}, "ForwardPath", $conf, $default, 35);

&option_input($text{'opts_minfree'}, "MinFreeBlocks",
	      $conf, $default, 8, $text{'opts_blocks'});
&option_input($text{'opts_maxmessage'}, "MaxMessageSize",
	      $conf, $default, 10, $text{'opts_bytes'});

&option_input($text{'opts_loglevel'}, "LogLevel", $conf, $default, 4);
($vstr, $v) = &find_option("SendMimeErrors", $conf);
print &ui_table_row(&hlink($text{'opts_mimebounce'}, "opt_SendMimeErrors"),
	&ui_radio("SendMimeErrors", $v eq "True" ? "True" : "False",
		  [ [ "True", $text{'yes'} ],
		    [ "False", $text{'no'} ] ]));

($gstr, $g) = &find_option("MatchGECOS", $conf);
print &ui_table_row(&hlink($text{'opts_gecos'}, "opt_MatchGECOS"),
	&ui_radio("MatchGECOS", $v eq "True" ? "True" : "False",
		  [ [ "True", $text{'yes'} ],
		    [ "False", $text{'no'} ] ]));
&option_input($text{'opts_hops'}, "MaxHopCount", $conf, $default, 4);

if ($ver >= 10) {
	&option_input($text{'opts_maxrcpt'}, "MaxRecipientsPerMessage",
		      $conf, $default, 4);
	&option_input($text{'opts_maxbad'}, "BadRcptThrottle",
		      $conf, $default, 4);
	}

($bstr, $b) = &find_option("DontBlameSendmail", $conf);
print &ui_table_row(&hlink($text{'opts_blame'}, "opt_DontBlameSendmail"),
	&ui_radio("DontBlameSendmail_def", $b ? 0 : 1,
		  [ [ 1, $text{'default'} ],
		    [ 0, $text{'opts_selected'} ] ])."<br>".
        &ui_select("DontBlameSendmail",
	 [ split(/[\s,]+/, $b) ],
	 [ map { [ $_->[0],
		   "$_->[0] (".(length($_->[1]) > 40 ? substr($_->[1], 0, 40)."..." : $_->[1]).")" ] } &list_dontblames() ],
	 5, 1, 1), 3);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'opts_save'} ] ]);

&ui_print_footer("", $text{'index_return'});

# option_input(desc, name, &config, default, size, units)
sub option_input
{
local ($vstr, $v) = &find_option($_[1], $_[2]);
print &ui_table_row(&hlink($_[0], "opt_".$_[1]),
	&ui_opt_textbox($_[1], $v, $_[4], $_[3])." ".$_[5],
	$_[4] > 20 ? 3 : 1);
}

# options_input(desc, name, &config, default, size, units)
sub options_input
{
local @vals = &find_options($_[1], $_[2]);
print &ui_table_row(&hlink($_[0], "opt_".$_[1]),
	&ui_radio("$_[1]_def", @vals ? 0 : 1,
		[ [ 1, $_[3] ], [ 0, $text{'opts_below'} ] ])."<br>".
	&ui_textarea($_[1], join("\n", map { $_->[1] } @vals), 3, $_[4]),
	$_[4] > 20 ? 3 : 1);
}

