#!/usr/local/bin/perl
# list_received.cgi
# Display a list of received voicemail messages

require './vgetty-lib.pl';
&ui_print_header(undef, $text{'received_title'}, "");

@conf = &get_config();
$dir = &receive_dir(\@conf);
opendir(DIR, $dir);
while($f = readdir(DIR)) {
	if ($f =~ /\.rmd$/) {
		local $info = &rmd_file_info("$dir/$f");
		push(@received, $info) if ($info);
		}
	}
closedir(DIR);

if (@received) {
	print "$text{'recieved_desc'}<p>\n";
	print "<form action=delete.cgi method=post>\n";
	print "<input type=hidden name=mode value=0>\n";
	print &select_all_link("del", 0, $text{'received_all'}),"&nbsp;\n";
	print &select_invert_link("del", 0, $text{'received_invert'}),"\n";
	print "<table border width=100%>\n";
	print "<tr $tb> <td><br></td> ",
	      "<td><b>$text{'received_date'}</b></td> ",
	      "<td><b>$text{'received_size'}</b></td> ",
	      "<td><b>$text{'received_speed'}</b></td> ",
	      "<td><b>$text{'received_type'}</b></td> </tr>\n";
	foreach $r (sort { $b->{'date'} <=> $a->{'date'} } @received) {
		print "<tr $cb>\n";
		print "<td><input type=checkbox name=del ",
		      "value='$r->{'file'}'></td>\n";
		print "<td><a href='listen.cgi/voicemail.wav?file=",
		      &urlize($r->{'file'}),"&mode=0'>",
		      scalar(localtime($r->{'date'})),"</a></td>\n";
		print "<td>",int($r->{'size'}/1024)." kB","</td>\n";
		print "<td>$r->{'speed'}</td>\n";
		print "<td>",&text('pvfdesc', $r->{'type'}, $r->{'bits'}),
		      "</td>\n";
		print "</tr>\n";
		}
	print "</table>\n";
	print &select_all_link("del", 0, $text{'received_all'}),"&nbsp;\n";
	print &select_invert_link("del", 0, $text{'received_invert'}),"<p>\n";
	print "<input type=submit value='$text{'received_delete'}'>&nbsp;\n";
	print "<input type=submit name=move ",
	      "value='$text{'received_move'}'></form>\n";
	}
else {
	print "<p><b>$text{'received_none'}</b> <p>\n";
	}

&ui_print_footer("", $text{'index_return'});

