#!/usr/local/bin/perl
# edit_anon.cgi
# Display anonymous access form

require './usermin-lib.pl';
&ui_print_header(undef, $text{'anon_title'}, "");
&get_usermin_miniserv_config(\%miniserv);

print $text{'anon_desc'},"<p>\n";
foreach $a (split(/\s+/, $miniserv{'anonymous'})) {
	if ($a =~ /^([^=]+)=(\S+)$/) {
		push(@anon, [ $1, $2 ]);
		}
	}

print &ui_form_start("change_anon.cgi");
print &ui_columns_start([ $text{'anon_url'},
                          $text{'anon_user'} ]);

push(@anon, scalar(@anon)%2 == 0 ? ( [ ], [ ] ) : ( [ ] ));

my $i = 0;
foreach $a (@anon) {
	print &ui_columns_row([
	  &ui_textbox("url_$i", $a->[0], 30),
	  &ui_textbox("user_$i", $a->[1], 20)]);
	$i++;
}

print &ui_columns_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

