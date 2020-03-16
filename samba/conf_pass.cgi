#!/usr/local/bin/perl
# conf_pass.cgi
# Display password options options

require './samba-lib.pl';

# check acls

&error_setup("$text{'eacl_aviol'}ask_epass.cgi");
&error("$text{'eacl_np'} $text{'eacl_pcp'}") unless $access{'conf_pass'};

&ui_print_header(undef, $text{'passwd_title'}, "");

&get_share("global");

print &ui_form_start("save_pass.cgi", "post");
print &ui_table_start($text{'passwd_title'}, undef, 2);

print &ui_table_row($text{'passwd_encrypt'},
	&yesno_input("encrypt passwords"));

print &ui_table_row($text{'passwd_allownull'},
	&yesno_input("null passwords"));

print &ui_table_row($text{'passwd_program'},
	&ui_opt_textbox("passwd_program", &getval("passwd program"), 25,
			$text{'default'}));

print &ui_table_row($text{'passwd_sync'},
	&yesno_input("unix password sync"));

$pc = &getval("passwd chat");
$chat = &ui_radio("passwd_chat_def", $pc eq "" ? 1 : 0,
		  [ [ 1, $text{'default'} ],
		    [ 0, $text{'passwd_below'} ] ])."<br>\n";
$chat .= &ui_columns_start([ $text{'passwd_waitfor'},
			     $text{'passwd_send'} ]);
while($pc =~ /^"([^"]*)"\s*(.*)/ || $pc =~ /^(\S+)\s*(.*)/) {
	if ($send) { push(@send, $1); $send = 0; }
	else { push(@recv, $1); $send = 1; }
	$pc = $2;
	}
for($i=0; $i<(@recv < 5 ? 5 : @recv+1); $i++) {
	$chat .= &ui_columns_row([
		&ui_textbox("chat_recv_$i",
			    $recv[$i] eq "." ? "" : $recv[$i], 20),
		&ui_textbox("chat_send_$i", $send[$i], 20),
		]);
	}
$chat .= &ui_columns_end();
print &ui_table_row($text{'passwd_chat'}, $chat);

$map = &ui_radio("username_map_def", &getval("username map") eq "" ? 1 : 0,
		 [ [ 1, $text{'config_none'} ],
		   [ 0, $text{'passwd_below'} ] ])."<br>\n";
$map .= &ui_columns_start([ $text{'passwd_unixuser'},
			    $text{'passwd_winuser'} ]);
open(UMAP, "<".&getval("username map"));
while(<UMAP>) {
	s/\r|\n//g;
	s/[#;].*$//g;
	if (/^\s*(\S+)\s*=\s*(.*)$/) {
		local $uunix = $1;
		local $rest = $2;
		while($rest =~ /^\s*"([^"]*)"(.*)$/ ||
		      $rest =~ /^\s*(\S+)(.*)$/) {
			push(@uunix, $uunix);
			push(@uwin, $1);
			$rest = $2;
			}
		}
	}
close(UMAP);
for($i=0; $i<@uunix+1; $i++) {
	$map .= &ui_columns_row([
		&ui_textbox("umap_unix_$i", $uunix[$i], 15),
		&ui_textbox("umap_win_$i", $uwin[$i], 30),
		]);
	}
$map .= &ui_columns_end();
print &ui_table_row($text{'passwd_map'}, $map);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_sharelist'});
