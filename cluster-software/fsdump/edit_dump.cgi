#!/usr/local/bin/perl
# edit_dump.cgi
# Edit or create a filesystem backup

require './fsdump-lib.pl';
&foreign_require("cron", "cron-lib.pl");
&ReadParse();

if (!$in{'id'}) {
	# Adding a new backup of some type
	$access{'edit'} || &error($text{'dump_ecannot1'});
	&error_setup($text{'edit_err'});
	$in{'dir'} || &error($text{'edit_edir'});
	if ($supports_tar && ($config{'always_tar'} || $in{'forcetar'})) {
		# Always use tar format
		$fs = "tar";
		}
	else {
		# Work out filesystem type
		$fs = &directory_filesystem($in{'dir'});
		@supp = &supported_filesystems();
		if (&indexof($fs, @supp) < 0) {
			if ($supports_tar) {
				$fs = "tar";		# fall back to tar mode
				}
			else {
				&error(&text('edit_efs', uc($fs)));
				}
			}
		}
	&ui_print_header(undef, $text{'edit_title'}, "", "edit");
	$dump = { 'dir' => $in{'dir'},
		  'fs' => $fs,
		   $config{'simple_sched'} ?
			( 'special' => 'daily' ) :
			( 'mins' => '0',
			  'hours' => '0',
			  'days' => '*',
			  'months' => '*',
			  'weekdays' => '*' ) };
	}
else {
	# Editing an existing backup
	$dump = &get_dump($in{'id'});
	$access{'edit'} && &can_edit_dir($dump) ||
		&error($text{'dump_ecannot2'});
	&ui_print_header(undef, $text{'edit_title2'}, "", "create");
	}

print "<form action=save_dump.cgi>\n";
print "<input type=hidden name=id value='$in{'id'}'>\n";
print "<input type=hidden name=fs value='$dump->{'fs'}'>\n";
print "<table border width=100%>\n";
print "<tr $tb> <td><b>",&text('edit_header', uc($dump->{'fs'})),
      "</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'dump_format'}</b></td>\n";
print "<td>",$dump->{'fs'} eq 'tar' ? $text{'dump_tar'}
		    : &text('dump_dumpfs', uc($dump->{'fs'})),"</td> </tr>\n";

if (!&multiple_directory_support($dump->{'fs'})) {
	# One directory
	print "<tr> <td><b>",&hlink($text{'dump_dir'}, "dir"),"</b></td>\n";
	printf "<td colspan=3>".
	       "<input name=dir size=50 value='%s'> %s</td> </tr>\n",
		$dump->{'dir'}, &file_chooser_button("dir", 1);
	}
else {
	# Multiple directories
	print "<tr> <td valign=top><b>",
		&hlink($text{'dump_dirs'}, "dirs"),"</b></td>\n";
	print "<td colspan=3><textarea name=dir rows=3 cols=50>",
		join("\n", &dump_directories($dump)),
		"</textarea></td> </tr>\n";
	}

&dump_form($dump);
if (defined(&dump_options_form)) {
	&new_header($text{'edit_header3'});
	&dump_options_form($dump);
	}

if (defined(&verify_dump)) {
	# Add option to verify, if supported
	print "<tr><td><b>",&hlink($text{'dump_reverify'},"reverify"),
	      "</b></td>\n";
	print "<td>",&ui_yesno_radio("reverify",
			int($dump->{'reverify'})),"</td> </tr>\n";
	}

if ($access{'extra'}) {
	print "<tr> <td><b>",&hlink($text{'dump_extra'}, "extra"),"</b></td>\n";
	printf "<td colspan=3><input name=extra size=60 value='%s'></td> </tr>\n",
		$dump->{'extra'};
	}

if ($access{'cmds'}) {
	print "<tr> <td><b>",&hlink($text{'dump_before'},"before"),"</b></td>\n";
	printf "<td colspan=3><input name=before size=60 value='%s'></td> </tr>\n",
		$dump->{'before'};

	print "<tr> <td><b>",&hlink($text{'dump_after'},"after"),"</b></td>\n";
	printf "<td colspan=3><input name=after size=60 value='%s'></td> </tr>\n",
		$dump->{'after'};
	}

&new_header($text{'edit_header2'});

# Show input for selecting when to run a dump, which can be never, on schedule
# or after some other dump
@dlist = grep { $_->{'id'} ne $in{'id'} } &list_dumps();
if (@dlist) {
	$follow = &ui_select("follow", $dump->{'follow'},
	    [ map { [ $_->{'id'},
		      &text(defined($_->{'level'}) ? 'edit_tolevel' : 'edit_to',
			    $_->{'dir'}, &dump_dest($_), $_->{'level'}) ] }
		  @dlist ]);
	}
print "<tr> <td valign=top><b>",&hlink($text{'edit_enabled'}, "enabled"),
      "</b></td>\n";
print "<td colspan=3>",
	&ui_radio("enabled", $dump->{'follow'} ? 2 :
				$dump->{'enabled'} ? 1 : 0,
	     [ [ 0, $text{'edit_enabled_no'}."<br>" ],
	       @dlist ? 
		( [ 2, $text{'edit_enabled_af'}." ".$follow."<br>" ] ) : ( ),
	       [ 1, $text{'edit_enabled_yes'} ] ]),"</td> </tr>\n";

# Email address to send output to
print "<tr> <td><b>",&hlink($text{'edit_email'}, "email"),"</b></td>\n";
printf "<td colspan=3><input name=email size=30 value='%s'></td> </tr>\n",
	$dump->{'email'};

# Subject line for email message
print "<tr> <td><b>",&hlink($text{'edit_subject'}, "subject"),"</b></td>\n";
printf "<td colspan=3><input type=radio name=subject_def value=1 %s> %s\n",
	$dump->{'subject'} ? "" : "checked", $text{'default'};
printf "<input type=radio name=subject_def value=0 %s>\n",
	$dump->{'subject'} ? "checked" : "";
printf "<input name=subject size=40 value='%s'></td> </tr>\n",
	$dump->{'subject'};

if (!$config{'simple_sched'} || ($dump && !$dump->{'special'})) {
	# Complex Cron time input
	print "</table>\n";
	print "<table border width=100%>\n";
	&foreign_call("cron", "show_times_input", $dump);
	print "</table>\n";
	}
else {
	# Simple input
	print &ui_hidden("special_def", 1),"\n";
	print "<tr> <td><b>",&hlink($text{'edit_special'}, "special"),"</b></td>\n";
	print "<td>",&ui_select("special", $dump->{'special'},
		[ map { [ $_, $cron::text{'edit_special_'.$_} ] }
		      ('hourly', 'daily', 'weekly', 'monthly', 'yearly') ]),
	      "</td> </tr>\n";
	print "</table>\n";
	}
print "</td></tr></table>\n";

print "<table width=100%><tr>\n";
if ($in{'id'}) {
	print "<td><input type=submit value='$text{'save'}'></td>\n";
	print "<td align=middle><input type=submit name=savenow ",
	      "value='$text{'edit_savenow'}'></td>\n";
	print "<td align=middle><input type=submit name=restore ",
	      "value='$text{'edit_restore'}'></td>\n";
	print "<td align=right><input type=submit name=delete ",
	      "value='$text{'delete'}'></td>\n";
	}
else {
	print "<td><input type=submit value='$text{'create'}'></td>\n";
	print "<td align=right><input type=submit name=savenow ",
	      "value='$text{'edit_createnow'}'></td>\n";
	}
print "</tr></table></form>\n";

&ui_print_footer("", $text{'index_return'});

