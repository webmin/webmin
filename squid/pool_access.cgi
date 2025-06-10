#!/usr/local/bin/perl
# pool_access.cgi
# A form for editing or creating delay pool ACL

use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'delay'} || &error($text{'delay_ecannot'});
&ReadParse();
my $conf = &get_config();

my @delay;
if (!defined($in{'index'})) {
	&ui_print_header(undef, $text{'apool_header'}, "",
		undef, 0, 0, 0, &restart_button());
	}
else {
	&ui_print_header(undef, $text{'apool_header1'}, "",
		undef, 0, 0, 0, &restart_button());
	@delay = @{$conf->[$in{'index'}]->{'values'}};
	}

print &ui_form_start("pool_access_save.cgi", "post");
print &ui_hidden("idx", $in{'idx'});
if (@delay) {
	print &ui_hidden("index", $in{'index'});
	}
print &ui_table_start($text{'apool_pr'}, undef, 2);

# Allow or deny ACLs
print &ui_table_row($text{'ahttp_a'},
	&ui_radio("action", $delay[1] || "allow",
		  [ [ "allow", $text{'ahttp_a1'} ],
		    [ "deny", $text{'ahttp_d'} ] ]));

# Get list of ACLs being matched, and all ACLs
my (@yes, @no);
for(my $i=2; $i<@delay; $i++) {
	if ($delay[$i] =~ /^!(.*)/) {
		push(@no, $1);
		}
	else {
		push(@yes, $delay[$i]);
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
		     @delay ? ( [ 'delete', $text{'buttdel'} ] ) : ( ) ]);

&ui_print_footer("edit_pool.cgi?idx=$in{'idx'}", $text{'pool_return'},
	"", $text{'index_return'});

