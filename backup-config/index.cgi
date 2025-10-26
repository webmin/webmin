#!/usr/local/bin/perl
# Show all scheduled backups, and a form for doing an immediate one

use strict;
use warnings;
use POSIX qw(strftime);
no warnings 'redefine';
no warnings 'uninitialized';
require './backup-config-lib.pl';
our (%text, %in, %config);
&ReadParse();

&ui_print_header(undef, $text{'index_title'}, "", undef, 1, 1);
my @mods = &list_backup_modules();
if (!@mods) {
	&ui_print_endpage($text{'index_emods'});
	}
my %mods = map { $_->{'dir'}, $_ } @mods;

# Show tabs
my @tabs = ( [ "backup", $text{'index_tabbackup'}, "index.cgi?mode=backup" ],
	     [ "sched", $text{'index_tabsched'}, "index.cgi?mode=sched" ],
	     [ "restore", $text{'index_tabrestore'}, "index.cgi?mode=restore" ],
	   );
print &ui_tabs_start(\@tabs, "tab", $in{'mode'} || "backup", 1);

print &ui_tabs_start_tab("tab", "sched");
my @backups = &list_backups();
my $using_strftime = 0;
if (@backups) {
	# Show all scheduled backups
	print &ui_link("edit.cgi?new=1", $text{'index_add'});
	print "<br>\n";
	print &ui_columns_start([ $text{'index_dest'},
			    	  $text{'index_mods'},
			    	  $text{'index_sched'} ], 100);
	foreach my $b (@backups) {
		my @m = map { $mods{$_}->{'desc'} }
			    split(/\s+/, $b->{'mods'});
		print &ui_columns_row(
			[ &ui_link("edit.cgi?id=".$b->{'id'},
			  &nice_dest($b->{'dest'}) ),
			  @m > 5 ? &text('index_count', scalar(@m))
				 : join(", ", @m),
			  $b->{'sched'} ? &text('index_when',
				&cron::when_text($b)) : $text{'no'} ]);
		$using_strftime++ if ($b->{'dest'} =~ /%/);
		}
	print &ui_columns_end();
	}
else {
	print "<strong>$text{'index_none'}</strong><br>\n";
	}
print &ui_link("edit.cgi?new=1", $text{'index_add'});
print "\n";
if ($using_strftime && !$config{'date_subs'}) {
	print &ui_alert_box($text{'index_nostrftime'}, 'warn'),"\n";
	}
print &ui_tabs_end_tab();

# Show immediate form
print &ui_tabs_start_tab("tab", "backup");
my $filename = 'webmin-backup-config-on-';
my $hostname = &get_system_hostname();
$hostname =~ s/\./-/g;
$filename .= $hostname;
$filename .= "-".strftime("%Y-%m-%d-%H-%M", localtime);
print &ui_form_start("backup.cgi/$filename.tgz", "post");
print &ui_table_start($text{'index_header'}, undef, 2);

my @dmods = split(/\s+/, $config{'mods'} || "");
print &ui_table_row($text{'edit_mods'},
		    &ui_select("mods", \@dmods,
		       [ map { [ $_->{'dir'}, $_->{'desc'} ] } @mods ],
		       10, 1));

print &ui_table_row($text{'edit_dest'},
		    &show_backup_destination("dest", $config{'dest'}, 2));

print &ui_table_row($text{'edit_what'},
		    &show_backup_what("what", $config{'configfile'},
					      $config{'nofiles'}));

print &ui_table_end();
print &ui_form_end([ [ 'backup', $text{'index_now'} ] ]);

print &ui_tabs_end_tab();

# Show restore form
print &ui_tabs_start_tab("tab", "restore");
print &ui_form_start("restore.cgi", "form-data");
print &ui_table_start($text{'index_header2'}, undef, 2);

print &ui_table_row($text{'edit_mods2'},
		    &ui_select("mods",
		       [ map { $_->{'dir'} } @mods ],
		       [ map { [ $_->{'dir'}, $_->{'desc'} ] } @mods ],
		       5, 1));

print &ui_table_row($text{'edit_other2'},
		    &ui_textarea("others", undef, 3, 50));

print &ui_table_row($text{'edit_dest2'},
		    &show_backup_destination("src", $config{'dest'}, 1));

print &ui_table_row($text{'index_apply'},
		    &ui_yesno_radio("apply", $config{'apply'} ? 1 : 0));

print &ui_table_row($text{'index_test'},
		    &ui_yesno_radio("test", 0));

print &ui_table_end();
print &ui_form_end([ [ 'restore', $text{'index_now2'} ] ]);

print &ui_tabs_end_tab();
print &ui_tabs_end(1);

&ui_print_footer("/", $text{'index'});

