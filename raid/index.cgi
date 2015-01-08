#!/usr/local/bin/perl
# Display all RAID devices

require './raid-lib.pl';

# Check if raid is installed
if (!-r $config{'mdstat'}) {
	&error_exit(&text('index_emdstat', "<tt>$config{'mdstat'}</tt>"));
	}
if (&has_command("mdadm")) {
	# Using mdadm commands
	$raid_mode = "mdadm";
	$raid_ver = &get_mdadm_version();
	}
elsif (&has_command('mkraid') && &has_command('raidstart')) {
	# Using raid tools commands
	$raid_mode = "raidtools";
	}
else {
	&error_exit($text{'index_eprogs'});
	}
&open_tempfile(MODE, ">$module_config_directory/mode");
&print_tempfile(MODE, $raid_mode,"\n");
&close_tempfile(MODE);

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("raid", "man", "doc"),
	undef, undef, &text('index_'.$raid_mode, $raid_ver));

# Display configured raid devices
$conf = &get_raidtab();
if (@$conf) {
	print &ui_columns_start([ $text{'index_name'},
				$raid_mode eq "raidtools" ? $text{'index_active'} : $text{'index_status'},
				$text{'index_level'},
				$text{'index_size'},
				$text{'index_members'} ]);
	foreach $c (@$conf) {
		$lvl = &find_value('raid-level', $c->{'members'});
		@mems = ( );
		foreach $d (&find('device', $c->{'members'})) {
			if (&find('raid-disk', $d->{'members'}) ||
			    &find('parity-disk', $d->{'members'})) {
				push(@mems, $d->{'value'});
				}
			}
		my @errors = grep { $_ ne "U" } @{$c->{'errors'}};
		print &ui_columns_row([
			&ui_link("view_raid.cgi?idx=$c->{'index'}",
				 &html_escape($c->{'value'})),
			$raid_mode eq "raidtools" ?
			  $c->{'active'} ?
			    "<font color=#00aa00>$text{'yes'}</font>" :
			    "<font color=#ff0000>$text{'no'}</font>" :
			$c->{'state'} =~ /resyncing/ ||
			  $c->{'state'} =~ /recovering/ ||
			  $c->{'state'} =~ /reshaping/ ||
			  $c->{'state'} =~ /degraded/ ||
			  $c->{'state'} =~ /FAILED/ ?
			    $c->{'rebuild'} ne '' ?
			      "<font color=#ff0000>".$c->{'state'}."(".$c->{'rebuild'}."%, ".int($c->{'remain'})."min)</font>" :
			      "<font color=#ff0000>".$c->{'state'}."</font>" :
			  @errors ?
			    "<font color=#ff8800>$text{'index_errors'}</font>" :
			    "<font color=#00aa00>".$c->{'state'}."</font>",
			$lvl eq 'linear' ? $text{'linear'} : $text{'raid'.$lvl},
			$c->{'size'} ? &nice_size($c->{'size'}*1024) : "",
			&ui_links_row(\@mems),
			]);
		}
	print &ui_columns_end();
	}
else {
	print "<p><b>$text{'index_none'}</b><p>\n";
	}
&show_button();

# Form for mdadm monitoring options
if ($raid_mode eq "mdadm") {
	$notif = &get_mdadm_notifications();
	print &ui_hr();
	print &ui_form_start("save_mdadm.cgi", "post");
	print &ui_table_start($text{'index_header'}, undef, 2, [ "width=30%" ]);

	# Is monitoring enabled?
	if (&get_mdadm_action()) {
		print &ui_table_row($text{'index_monitor'},
		   &ui_yesno_radio("monitor", &get_mdadm_monitoring() ? 1 : 0));
		}

	# Notification address
	print &ui_table_row($text{'index_mailaddr'},
		&ui_opt_textbox("mailaddr", $notif->{'MAILADDR'}, 40,
				$text{'index_mailaddrnone'}));

	# Notification sender
	print &ui_table_row($text{'index_mailfrom'},
		&ui_opt_textbox("mailfrom", $notif->{'MAILFROM'}, 40,
				$text{'index_mailfromnone'}));

	# Program to call for problems
	print &ui_table_row($text{'index_program'},
		&ui_opt_textbox("program", $notif->{'PROGRAM'}, 40,
				$text{'index_programnone'}));

	print &ui_table_end();
	print &ui_form_end([ [ undef, $text{'save'} ] ]);
	}

&ui_print_footer("/", $text{'index'});

sub show_button
{
print &ui_form_start("raid_form.cgi");
print &ui_submit($text{'index_add'});
local @levels = &get_raid_levels();
print &ui_select("level", "linear",
		 [ [ "linear", $text{'linear'} ],
		   map { [ $_, $text{'raid'.$_} ] } @levels ]),"\n";
print &ui_form_end();
}

sub error_exit
{
&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1, 0,
	&help_search_link("raid", "man", "doc"));
print "<p><b>",@_,"</b><p>\n";
&ui_print_footer("/", $text{'index'});
exit;
}

