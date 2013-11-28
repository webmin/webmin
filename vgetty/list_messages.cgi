#!/usr/local/bin/perl
# list_messages.cgi
# Display a list of messages for answering machine use.
# - If there is no Index file, assume just standard.rmd
# - Allow uploading in different formats, with modem conversion

require './vgetty-lib.pl';
&ui_print_header(undef, $text{'messages_title'}, "");

@conf = &get_config();
$dir = &messages_dir(\@conf);
$index = &messages_index(\@conf);
open(INDEX, $index);
while(<INDEX>) {
	s/\r|\n//g;
	push(@messages, &rmd_file_info("$dir/$_"));
	}
close(INDEX);
if (!@messages) {
	$bak = &find_value("backup_message", \@conf);
	$info = &rmd_file_info("$dir/$bak");
	push(@messages, $info) if ($info);
	}

print "$text{'messages_desc'}<p>\n";
if (@messages) {
	print "<form action=delete.cgi method=post>\n";
	print "<input type=hidden name=mode value=1>\n";
	print &select_all_link("del", 0, $text{'received_all'}),"&nbsp;\n";
	print &select_invert_link("del", 0, $text{'received_invert'}),"\n";
	print "<table border width=100%>\n";
	print "<tr $tb> <td><br></td> ",
	      "<td><b>$text{'messages_file'}</b></td> ",
	      "<td><b>$text{'received_size'}</b></td> ",
	      "<td><b>$text{'received_speed'}</b></td> ",
	      "<td><b>$text{'received_type'}</b></td> </tr>\n";
	foreach $r (sort { $a->{'file'} <=> $b->{'file'} } @messages) {
		print "<tr $cb>\n";
		print "<td><input type=checkbox name=del ",
		      "value='$r->{'file'}'></td>\n";
		print "<td><a href='listen.cgi/voicemail.wav?file=",
		      &urlize($r->{'file'}),"&mode=1'>",
		      $r->{'file'},"</a></td>\n";
		print "<td>",int($r->{'size'}/1024)." kB","</td>\n";
		print "<td>$r->{'speed'}</td>\n";
		print "<td>",&text('pvfdesc', $r->{'type'}, $r->{'bits'}),
		      "</td>\n";
		print "</tr>\n";
		}
	print "</table>\n";
	print &select_all_link("del", 0, $text{'received_all'}),"&nbsp;\n";
	print &select_invert_link("del", 0, $text{'received_invert'}),"<p>\n";
	print "<input type=submit value='$text{'received_delete'}'></form>\n";
	}
else {
	print "<p><b>$text{'messages_none'}</b> <p>\n";
	}

print &ui_hr();
print "$text{'messages_updesc'}<p>\n";
print "<form action=upload.cgi method=post enctype=multipart/form-data>\n";
print "<input type=submit value='$text{'messages_upload'}'>\n";
print "<input name=wav type=file>\n";
print "$text{'messages_fmt'} <select name=format>\n";
foreach $f (&list_rmd_formats()) {
	printf "<option value='%s' %s>%s</option>\n",
		$f->{'index'},
		$f->{'index'} == $config{'format'} ? "selected" : "",
		$f->{'desc'};
	}
print "</select></form>\n";

&ui_print_footer("", $text{'index_return'});

