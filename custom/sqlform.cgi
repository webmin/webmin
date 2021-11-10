#!/usr/local/bin/perl
# sqlform.cgi
# Display the form for one SQL command on a page

require './custom-lib.pl';
&ReadParse();
$cmd = &get_command($in{'id'}, $in{'idx'});
&can_run_command($cmd) || &error($text{'form_ecannot'});

# Display form for command parameters
&ui_print_header(undef, $text{'form_title'}, "");
@a = @{$cmd->{'args'}};
($up) = grep { $_->{'type'} == 10 } @a;
if ($up) {
	print &ui_form_start("sql.cgi", "form-data");
	}
elsif (@a) {
	print &ui_form_start("sql.cgi", "post");
	}
else {
	print &ui_form_start("sql.cgi");
	}
print &ui_hidden("id", $cmd->{'id'});
print &ui_table_start($cmd->{'html'} || $cmd->{'desc'}, "width=100%", 4,
		      [ "width=20%", "width=30%", "width=20%", "width=30%" ]);

foreach $a (@{$cmd->{'args'}}) {
	print &ui_table_row(&html_escape($a->{'desc'}),
		&show_parameter_input($a, 0), 2);
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'form_exec'} ] ]);

&ui_print_footer("", $text{'index_return'});

