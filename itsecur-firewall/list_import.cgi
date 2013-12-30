#!/usr/bin/perl
# Show a form for importing rules in CSV format

require './itsecur-lib.pl';
&can_edit_error("import");
&check_zip();
&header($text{'import_title'}, "",
	undef, undef, undef, undef, &apply_button());

foreach my $i (1 .. (&supports_time() ? 4 : 3)) {
	my $prog = $i == 1 ? "import_rules.cgi" :
		$i == 2 ? "import_servs.cgi" :
		$i == 3 ? "import_groups.cgi" :
		$i == 4 ? "import_times.cgi" : undef;
	print &ui_hr();
	print $text{'import_desc'.$i},"<p>\n";
    print &ui_form_start($prog,"form-data");
    print &ui_table_start($text{'import_header'.$i}, undef, 2);

	# Show source
    print &ui_table_row($text{'import_src'},
                &ui_radio("src_def",($mode == 1 ? 0 : 1),[
                    [1,$text{'restore_src1'}."&nbsp;".&ui_upload("file",20)."<br>"],
                    [0,$text{'restore_src0'}."&nbsp;".&ui_filebox("src",($mode == 1 ? $dest[0] : undef),40)]
                    ])
            );
                   

	print &ui_table_end();
    print "<p>";
    print &ui_submit($text{'import_ok'});
    print &ui_form_end(undef,undef,1);
	}

print &ui_hr();
&footer("", $text{'index_return'});

