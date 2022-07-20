#!/usr/local/bin/perl
# http_access.cgi
# A form for editing or creating a proxy REPLY access restriction

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'actrl'} || &error($text{'eacl_ecannot'});
&ReadParse();
my $conf = &get_config();

my @http;
if (!defined($in{'index'})) {
	&ui_print_header(undef, $text{'ahttp_replyheader'}, "",
		undef, 0, 0, 0, &restart_button());
	}
else {
	&ui_print_header(undef, $text{'ahttp_replyheader1'}, "",
		undef, 0, 0, 0, &restart_button());
	@http = @{$conf->[$in{'index'}]->{'values'}};
	}

print &ui_form_start("http_reply_access_save.cgi", "post");
if (@http) {
	print &ui_hidden("index", $in{'index'});
	}
print &ui_table_start($text{'ahttp_replypr'}, undef, 2);

# Allow or deny ACLs
print &ui_table_row($text{'ahttp_a'},
	&ui_radio("action", $http[0] || "allow",
		  [ [ "allow", $text{'ahttp_a1'} ],
		    [ "deny", $text{'ahttp_d'} ] ]));

# Get list of ACLs being matched, and all ACLs
my (@yes, @no);
for(my $i=1; $i<@http; $i++) {
	if ($http[$i] =~ /^!(.*)/) {
		push(@no, $1);
		}
	else {
		push(@yes, $http[$i]);
		}
	}
my %done;
my @acls = grep { !$done{$_->{'values'}->[0]}++ } &find_config("acl", $conf);
unshift(@acls, { 'values' => [ 'all' ] }) if ($squid_version >= 3);
my $r = @acls;
$r = 10 if ($r > 10);

print &ui_table_row($text{'ahttp_ma'},
	&ui_select("yes", \@yes, [ map { $_->{'values'}->[0] } @acls ],
		   $r, 1, 1));

print &ui_table_row($text{'ahttp_dma'},
	&ui_select("no", \@no, [ map { $_->{'values'}->[0] } @acls ],
		   $r, 1, 1));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'buttsave'} ],
		     @http ? ( [ 'delete', $text{'buttdel'} ] ) : ( ) ]);

&ui_print_footer("edit_acl.cgi?mode=reply", $text{'ahttp_return'},
		 "", $text{'index_return'});

