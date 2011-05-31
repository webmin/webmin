#!/usr/local/bin/perl
# search_user.cgi
# Search the password file, and display a list of results

require './user-lib.pl';
&ReadParse();

# Build fields to search
$m = $in{'match'};
$w = lc($in{'what'});
@fields = ( );
if ($in{'field'} eq "group") {
	@fields = ( 'gid' );
	$w = &my_getgrnam($w) || $w;
	}
elsif ($in{'field'} eq 'userreal') {
	@fields = ( 'user', 'real' );
	}
else {
	@fields = ( $in{'field'} );
	}

# Search users for matches
@ulist = &list_users();
for($i=0; $i<@ulist; $i++) {
	$u = $ulist[$i];
	FIELD: foreach my $field (@fields) {
		$f = lc($u->{$field});
		if ($m == 0 && $f eq $w ||
		    $m == 1 && eval { $f =~ /$w/i } ||
		    $m == 4 && index($f, $w) >= 0 ||
		    $m == 2 && $f ne $w ||
		    $m == 3 && eval { $f !~ /$w/i } ||
		    $m == 5 && index($f, $w) < 0 ||
		    $m == 6 && $f < $w ||
		    $m == 7 && $f > $w) {
			if (&can_edit_user(\%access, $u)) {
				push(@match, $u);
				last FIELD;
				}
			}
		}
	}
if (@match == 1) {
	&redirect("edit_user.cgi?user=".$match[0]->{'user'});
	}
else {
	&ui_print_header(undef, $text{'search_title'}, "");
	if (@match == 0) {
		print "<b>$text{'search_notfound'}</b>. <p>\n";
		}
	else {
		print "<b>",&text('search_found', scalar(@match)),"</b><br>\n";
		@match = &sort_users(\@match, $config{'sort_mode'});
		&users_table(\@match);
		}
	&ui_print_footer("", $text{'index_return'});
	}

