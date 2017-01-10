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
		  'rsh' => &has_command("ssh"),
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
	if ($in{'clone'}) {
		&ui_print_header(undef, $text{'edit_title3'}, "", "create");
		delete($in{'id'});
		}
	else {
		&ui_print_header(undef, $text{'edit_title2'}, "", "create");
		}
	}

@tds = ( "width=30%" );
print &ui_form_start("save_dump.cgi", "post");
print &ui_hidden("id", $in{'id'}),"\n";
print &ui_hidden("fs", $dump->{'fs'}),"\n";
print &ui_hidden_table_start(&text('edit_header', uc($dump->{'fs'})),
		             "width=100%", 2, "source", 1);

print &ui_table_row($text{'dump_format'},
	$dump->{'fs'} eq 'tar' ? $text{'dump_tar'}
		    : &text('dump_dumpfs', uc($dump->{'fs'})),
	undef, \@tds);

if (!&multiple_directory_support($dump->{'fs'})) {
	# One directory
	print &ui_table_row(&hlink($text{'dump_dir'}, "dir"),
			    &ui_textbox("dir", $dump->{'dir'}, 50)."\n".
			    &file_chooser_button("dir", 1),
			    undef, \@tds);
	}
else {
	# Multiple directories
	print &ui_table_row(&hlink($text{'dump_dirs'}, "dirs"),
		    &ui_textarea("dir", join("\n", &dump_directories($dump)),
				 3, 50),
		    undef, \@tds);
	}

&dump_form($dump, \@tds);
print &ui_hidden_table_end();

print &ui_hidden_table_start($text{'edit_header3'}, "width=100%", 4, "opts", 0);
if (defined(&dump_options_form)) {
	&dump_options_form($dump, \@tds);
	}

if (defined(&verify_dump)) {
	# Add option to verify, if supported
	print &ui_table_row(&hlink($text{'dump_reverify'},"reverify"),
			    &ui_yesno_radio("reverify",
					    int($dump->{'reverify'})),
			    \@tds);
	}

# Extra command-line parameters
if ($access{'extra'}) {
	print &ui_table_row(&hlink($text{'dump_extra'}, "extra"),
			    &ui_textbox("extra", $dump->{'extra'}, 60), 3,
			    \@tds);
	}

# Before and after commands
if ($access{'cmds'}) {
	print &ui_table_row(&hlink($text{'dump_before'},"before"),
			    &ui_textbox("before", $dump->{'before'}, 60)."<br>".
			    &ui_checkbox("beforefok", 1, $text{'dump_fok'},
					 !$dump->{'beforefok'}),
			    3, \@tds);

	print &ui_table_row(&hlink($text{'dump_after'},"after"),
			    &ui_textbox("after", $dump->{'after'}, 60)."<br>".
			    &ui_checkbox("afterfok", 1, $text{'dump_fok2'},
					 !$dump->{'afterfok'})."<br>".
			    &ui_checkbox("afteraok", 1, $text{'dump_aok'},
                                         !$dump->{'afteraok'}),
			    3, \@tds);
	}
print &ui_hidden_table_end();

print &ui_hidden_table_start($text{'edit_header2'}, "width=100%", 4,
			     "sched", 0);

# Show input for selecting when to run a dump, which can be never, on schedule
# or after some other dump
@dlist = grep { $_->{'id'} ne $in{'id'} } &list_dumps();
if (@dlist) {
	$follow = &ui_select("follow", $dump->{'follow'},
	    [ map { [ $_->{'id'}, &follow_desc($_) ] } @dlist ]);
	}
print &ui_table_row(&hlink($text{'edit_enabled'}, "enabled"),
	&ui_radio("enabled", $dump->{'follow'} ? 2 :
				$dump->{'enabled'} ? 1 : 0,
	     [ [ 0, $text{'edit_enabled_no'}."<br>" ],
	       @dlist ? 
		( [ 2, $text{'edit_enabled_af'}." ".$follow."<br>" ] ) : ( ),
	       [ 1, $text{'edit_enabled_yes'} ] ]), 3, \@tds);

# Email address to send output to
print &ui_table_row(&hlink($text{'edit_email'}, "email"),
		    &ui_textbox("email", $dump->{'email'}, 30), 3, \@tds);

# Subject line for email message
print &ui_table_row(&hlink($text{'edit_subject'}, "subject"),
		    &ui_opt_textbox("subject", $dump->{'subject'},
				    40, $text{'default'}), 3, \@tds);

if (!$config{'simple_sched'} || ($dump && !$dump->{'special'})) {
	# Complex Cron time input
	print &cron::get_times_input($dump, 0, 4, $text{'edit_when'});
	}
else {
	# Simple input
	print &ui_hidden("special_def", 1),"\n";
	print &ui_table_row(&hlink($text{'edit_special'}, "special"),
		&ui_select("special", $dump->{'special'},
		    [ map { [ $_, $cron::text{'edit_special_'.$_} ] }
			  ('hourly', 'daily', 'weekly', 'monthly', 'yearly') ]),
		3, \@tds);
	}
print &ui_hidden_table_end();

if ($in{'id'}) {
	print &ui_form_end([ [ "save", $text{'save'} ],
			     [ "savenow", $text{'edit_savenow'} ],
			     [ "restore", $text{'edit_restore'} ],
			     [ "clone", $text{'edit_clone'} ],
			     [ "delete", $text{'delete'} ] ]);
	}
else {
	print &ui_form_end([ [ "create", $text{'create'} ],
			     [ "savenow", $text{'edit_createnow'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});

# follow_desc(&dump)
sub follow_desc
{
local @dirs = &dump_directories($_[0]);
return &text(defined($_[0]->{'level'}) ? 'edit_tolevel' : 'edit_to',
	     $dirs[0], &dump_dest($_[0]), $_[0]->{'level'});
}
