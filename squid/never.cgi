#!/usr/local/bin/perl
# never.cgi
# A form for editing or creating http_access directives

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'othercaches'} || &error($text{'eicp_ecannot'});
&ReadParse();
my $conf = &get_config();

my @never;
if (!defined($in{'index'})) {
	&ui_print_header(undef, $text{'never_create'}, "",
		undef, 0, 0, 0, &restart_button());
	}
else {
	&ui_print_header(undef, $text{'never_edit'}, "",
		undef, 0, 0, 0, &restart_button());
	@never = @{$conf->[$in{'index'}]->{'values'}};
	}

print &ui_form_start("never_save.cgi", "post");
if (@never) {
	print &ui_hidden("index", $in{'index'});
	}
print &ui_table_start($text{'never_header'}, undef, 2);

# Allow or deny this ACL?
print &ui_table_row($text{'ahttp_a'},
	&ui_radio("action", $never[0] || "allow",
		  [ [ "allow", $text{'ahttp_a1'} ],
		    [ "deny", $text{'ahttp_d'} ] ]));


# Get list of ACLs being matched, and all ACLs
my (@yes, @no);
for(my $i=1; $i<@never; $i++) {
	if ($never[$i] =~ /^!(.*)/) {
		push(@no, $1);
		}
	else {
		push(@yes, $never[$i]);
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
		     @never ? ( [ 'delete', $text{'buttdel'} ] ) : ( ) ]);

&ui_print_footer("edit_icp.cgi", $text{'ahttp_return'});

