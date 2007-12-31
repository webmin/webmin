#!/usr/local/bin/perl
# form.cgi
# Display the form for one custom command on a page

require './custom-lib.pl';
&ReadParse();
@cmds = &list_commands();
$cmd = $cmds[$in{'idx'}];
&can_run_command($cmd) || &error($text{'form_ecannot'});

# Display form for command parameters
&ui_print_header(undef, $text{'form_title'}, "");
@a = @{$cmd->{'args'}};
($up) = grep { $_->{'type'} == 10 } @a;
if ($cmd->{'edit'}) {
	print &ui_form_start("view.cgi");
	}
elsif ($up) {
	print &ui_form_start("run.cgi", "form-data");
	}
elsif (@a) {
	print &ui_form_start("run.cgi", "post");
	}
else {
	print &ui_form_start("run.cgi");
	}
print &ui_hidden("idx", $in{'idx'});
print &ui_table_start(&html_escape($cmd->{'desc'}), "width=100%", 4,
		      [ "width=20%", "width=30%", "width=20%", "width=30%" ]);
print &ui_table_row(undef, $cmd->{'html'}, 4) if ($cmd->{'html'});

foreach $a (@{$cmd->{'args'}}) {
	print &ui_table_row(&html_escape($a->{'desc'}),
		&show_parameter_input($a, 0));
	}

$txt = $cmd->{'edit'} ? $text{'form_edit'} : $text{'form_exec'};
print &ui_table_end();
print &ui_form_end([ [ undef, $txt ] ]);

&ui_print_footer("", $text{'index_return'});

