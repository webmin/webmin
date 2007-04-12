#!/usr/local/bin/perl
# Display per-user and group logout times options

require './usermin-lib.pl';
$access{'logout'} || &error($text{'logout_ecannot'});
&ui_print_header(undef, $text{'logout_title'}, "");
&get_usermin_miniserv_config(\%miniserv);

print $text{'logout_desc'},"<p>\n";
foreach $a (split(/\s+/, $miniserv{'logouttimes'})) {
	if ($a =~ /^([^=]+)=(\S+)$/) {
		push(@logout, [ $1, $2 ]);
		}
	}

print &ui_form_start("save_logout.cgi", "post");
print &ui_columns_start([ $text{'logout_type'},
			  $text{'logout_who'},
			  $text{'logout_time'} ]);
$i = 0;
foreach $l (@logout, [ ], [ ], [ ]) {
	local ($type, $who) = (0, $l->[0]);
	if ($l->[0] =~ /^\@(.*)$/) {
		$type = 2;
		$who = $1;
		}
	elsif ($l->[0] =~ /^(\/.*)$/) {
		$type = 3;
		}
	elsif ($l->[0]) {
		$type = 1;
		}
	print &ui_columns_row([
		&ui_select("type_$i", $type,
			   [ [ 0, "&nbsp;" ],
			     [ 1, $text{'logout_user'} ],
			     [ 2, $text{'logout_group'} ],
			     [ 3, $text{'logout_file'} ] ]),
		&ui_textbox("who_$i", $who, 30),
		&ui_textbox("time_$i", $l->[1], 6) ]);
	$i++;
	}
print &ui_columns_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
