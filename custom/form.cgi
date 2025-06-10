#!/usr/local/bin/perl
# form.cgi
# Display the form for one custom command on a page

require './custom-lib.pl';
&ReadParse();
$cmd = &get_command($in{'id'}, $in{'idx'});
&can_run_command($cmd) || &error($text{'form_ecannot'});

# Display form for command parameters
&ui_print_header(undef, $text{'form_title'}, "");
@a = @{$cmd->{'args'}};
@up = grep { $_->{'type'} == 10 } @a;
if ($cmd->{'edit'}) {
	print &ui_form_start("view.cgi");
	}
elsif (@up) {
	# Has upload fields
	@ufn = map { $_->{'name'} } @up;
	$upid = time().$$;
	print &ui_form_start("run.cgi?id=$upid",
	  "form-data", undef,
	  &read_parse_mime_javascript($upid, \@ufn));
	}
elsif (@a) {
	print &ui_form_start("run.cgi", "post");
	}
else {
	print &ui_form_start("run.cgi");
	}
print &ui_hidden("id", $cmd->{'id'});
print &ui_table_start($cmd->{'html'} || $cmd->{'desc'}, "width=100%", 4,
		      [ "width=20%", "width=30%", "width=20%", "width=30%" ]);

foreach $a (@{$cmd->{'args'}}) {
	print &ui_table_row(&html_escape($a->{'desc'}),
			    &show_parameter_input($a, 0), 2,
			    [ "valign=top", "valign=top" ]);
	$got_submit++ if ($a->{'type'} == 16);
	}

$txt = $cmd->{'edit'} ? $text{'form_edit'} : $text{'form_exec'};
print &ui_table_end();
print &ui_form_end($got_submit ? [ ] : [ [ undef, $txt ] ]);

&ui_print_footer("", $text{'index_return'});

