#!/usr/local/bin/perl
# open_files.cgi
# Display files and network connections that a process has open

require './proc-lib.pl';
&ReadParse();
&ui_print_header(undef, $text{'open_title'}, "", "open_proc");
%pinfo = &process_info($in{'pid'});
&can_edit_process($pinfo{'user'}) || &error($text{'edit_ecannot'});
if (!%pinfo) {
	print "<b>$text{'edit_gone'}</b> <p>\n";
	&ui_print_footer("", $text{'index_return'});
	exit;
	}

print "<b>",&text('open_proc', "<tt>$pinfo{'args'}</tt>", $in{'pid'}),
      "</b><p>\n";

# Show open files
print &ui_subheading($text{'open_header1'});
@files = &find_process_files($in{'pid'});
print &ui_columns_start([ $text{'open_fd'},
			  $text{'open_type'},
			  $text{'open_size'},
			  $text{'open_inode'},
			  $text{'open_file'} ], 100, 0);
foreach $f (@files) {
	print &ui_columns_row([
		     $f->{'fd'} eq 'cwd' ? $text{'open_cwd'} :
		     $f->{'fd'} eq 'rtd' ? $text{'open_rtd'} :
		     $f->{'fd'} eq 'txt' ? $text{'open_txt'} :
		     $f->{'fd'} eq 'mem' ? $text{'open_mem'} :
					   $f->{'fd'},
		     $f->{'type'} =~ /^v?dir$/ ? $text{'open_dir'} :
		     $f->{'type'} =~ /^v?reg$/ ? $text{'open_reg'} :
		     $f->{'type'} =~ /^v?chr$/ ? $text{'open_chr'} :
		     $f->{'type'} =~ /^v?blk$/ ? $text{'open_blk'} :
					     $f->{'type'},
		     $f->{'size'},
		     $f->{'inode'},
		     $f->{'file'},
		     ]);
	}
print &ui_columns_end();

# Show network connections
@nets = &find_process_sockets($in{'pid'});
if (@nets) {
	print &ui_subheading($text{'open_header2'});

	print &ui_columns_start([ $text{'open_type'},
				  $text{'open_proto'},
				  $text{'open_fd'},
				  $text{'open_desc'} ], 100, 0,
				[ "", "", "", "colspan=4" ]);
	foreach $n (@nets) {
		@cols = ( uc($n->{'type'}),
			  uc($n->{'proto'}),
			  $n->{'fd'} );
		@tds = ( "", "", "" );
		if ($n->{'listen'} && $n->{'lhost'} eq '*') {
			push(@cols, &text('open_listen1',
					  "<tt>$n->{'lport'}</tt>"));
			push(@tds, "colspan=4");
			}
		elsif ($n->{'listen'}) {
			push(@cols, &text('open_listen2',
					  "<tt>$n->{'lhost'}</tt>",
				          "<tt>$n->{'lport'}</tt>"));
			push(@tds, "colspan=4");
			}
		elsif ($n->{'rhost'}) {
			push(@cols, "<tt>$n->{'lhost'}:$n->{'lport'}</tt>",
				    "<tt>-&gt;</tt>",
				    "<tt>$n->{'rhost'}:$n->{'rport'}</tt>",
				    "<tt>$n->{'state'}</tt>");
			}
		else {
			push(@cols, &text('open_recv', "<tt>$n->{'lhost'}</tt>",
				      "<tt>$n->{'lport'}</tt>"));
			push(@tds, "colspan=4");
			}
		print &ui_columns_row(\@cols, \@tds);
		}
	print &ui_columns_end();
	}

&ui_print_footer("edit_proc.cgi?$in{'pid'}", $text{'edit_return'},
		 "", $text{'index_return'});
