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
@files = &find_process_files($in{'pid'});
print "<table border width=100%>\n";
print "<tr $tb> <td><b>$text{'open_header1'}</b></td> </tr>\n";
print "<tr $cb> <td><table width=100%>\n";

print "<tr> <td><b>$text{'open_fd'}</b></td> ",
      "<td><b>$text{'open_type'}</b></td> ",
      "<td><b>$text{'open_size'}</b></td> ",
      "<td><b>$text{'open_inode'}</b></td> ",
      "<td><b>$text{'open_file'}</b></td> </tr>\n";
foreach $f (@files) {
	print "<tr>\n";
	print "<td>",$f->{'fd'} eq 'cwd' ? $text{'open_cwd'} :
		     $f->{'fd'} eq 'rtd' ? $text{'open_rtd'} :
		     $f->{'fd'} eq 'txt' ? $text{'open_txt'} :
		     $f->{'fd'} eq 'mem' ? $text{'open_mem'} :
					   $f->{'fd'},"</td>\n";
	print "<td>",$f->{'type'} =~ /^v?dir$/ ? $text{'open_dir'} :
		     $f->{'type'} =~ /^v?reg$/ ? $text{'open_reg'} :
		     $f->{'type'} =~ /^v?chr$/ ? $text{'open_chr'} :
		     $f->{'type'} =~ /^v?blk$/ ? $text{'open_blk'} :
					     $f->{'type'},"</td>\n";
	print "<td>",$f->{'size'} || "<br>","</td>\n";
	print "<td>$f->{'inode'}</td>\n";
	print "<td>$f->{'file'}</td>\n";
	print "</tr>\n";
	}
print "</table></td></tr></table><p>\n";

# Show network connections
@nets = &find_process_sockets($in{'pid'});
if (@nets) {
	print "<table border width=100%>\n";
	print "<tr $tb> <td><b>$text{'open_header2'}</b></td> </tr>\n";
	print "<tr $cb> <td><table width=100%>\n";

	print "<tr> <td><b>$text{'open_type'}</b></td> ",
	      "<td><b>$text{'open_proto'}</b></td> ",
	      "<td><b>$text{'open_fd'}</b></td> ",
	      "<td colspan=4><b>$text{'open_desc'}</b></td> </tr>\n";
	foreach $n (@nets) {
		print "<tr>\n";
		print "<td>",uc($n->{'type'}),"</td>\n";
		print "<td>",uc($n->{'proto'}),"</td>\n";
		print "<td>",$n->{'fd'},"</td>\n";
		if ($n->{'listen'} && $n->{'lhost'} eq '*') {
			print "<td colspan=4>",
				&text('open_listen1', "<tt>$n->{'lport'}</tt>"),
				"</td>\n";
			}
		elsif ($n->{'listen'}) {
			print "<td colspan=4>",
				&text('open_listen2', "<tt>$n->{'lhost'}</tt>",
				      "<tt>$n->{'lport'}</tt>"),"</td>\n";
			}
		elsif ($n->{'rhost'}) {
			print "<td><tt>$n->{'lhost'}:$n->{'lport'}</tt></td>\n";
			print "<td><tt>-&gt;</tt></td>\n";
			print "<td><tt>$n->{'rhost'}:$n->{'rport'}</tt></td>\n";
			print "<td><tt>$n->{'state'}</tt></td>\n";
			}
		else {
			print "<td colspan=4>",
				&text('open_recv', "<tt>$n->{'lhost'}</tt>",
				      "<tt>$n->{'lport'}</tt>"),"</td>\n";
			}
		print "</tr>\n";
		}
	print "</table></td></tr></table>\n";
	}

&ui_print_footer("edit_proc.cgi?$in{'pid'}", $text{'edit_return'},
		 "", $text{'index_return'});
