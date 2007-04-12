#!/usr/local/bin/perl
# hide_form.cgi
# Build up a list of modules that should be hidden due to their managed
# servers not being installed

require './acl-lib.pl';
&ReadParse();
if ($in{'user'}) {
	&can_edit_user($in{'user'}) || &error($text{'edit_euser'});
	$what = $in{'user'};
	@whos = &list_users();
	}
else {
	$access{'groups'} || &error($text{'gedit_ecannot'});
	$what = $in{'group'};
	@whos = &list_groups();
	}
($who) = grep { $_->{'name'} eq $what } @whos;
&ui_print_header(undef, $text{'hide_title'}, "");

# Find modules to hide which the user has and which theoretically support
# this OS
%got = map { $_, 1 } @{$who->{'modules'}};
foreach $m (sort { $a->{'desc'} cmp $b->{'desc'} }
	    &get_all_module_infos()) {
	if (&check_os_support($m) && $got{$m->{'dir'}} &&
	    !&foreign_installed($m->{'dir'}, 0)) {
		push(@hide, $m);
		}
	}

if (@hide) {
	print "<form action=hide.cgi>\n";
	print "<input type=hidden name=user value='$in{'user'}'>\n";
	print "<input type=hidden name=group value='$in{'group'}'>\n";
	print &text('hide_desc', "<tt>$what</tt>"),"<br>\n";
	print "<ul>\n";
	foreach $h (@hide) {
		print "<li>$h->{'desc'}\n";
		if ($h->{'clone'}) {
			print &text('hide_clone', "<tt>$h->{'dir'}</tt>"),"\n";
			}
		print "<input type=hidden name=hide value='$h->{'dir'}'>\n";
		}
	print "</ul><p>\n";
	print "$text{'hide_desc2'}<p>\n";
	print "<input type=submit value='$text{'hide_ok'}'></form>\n";
	}
else {
	print &text('hide_none', "<tt>$what</tt>"),"<p>\n";
	}

&ui_print_footer(
	$in{'user'} ? ( "edit_user.cgi?user=$who", $text{'edit_return'} )
		    : ( "edit_group.cgi?group=$who", $text{'edit_return2'} ),
	"", $text{'index_return'});

