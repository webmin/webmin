#!/usr/local/bin/perl
# A form for editing or creating a header access control rule

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'headeracc'} || &error($text{'header_ecannot'});
&ReadParse();
my $conf = &get_config();

my @v;
if (!defined($in{'index'})) {
	&ui_print_header(undef, $text{'header_create_'.$in{'type'}} ||
				$text{'header_create'}, "",
		undef, 0, 0, 0, &restart_button());
	}
else {
	&ui_print_header(undef, $text{'header_edit_'.$in{'type'}} ||
				$text{'header_edit'}, "",
		undef, 0, 0, 0, &restart_button());
	@v = @{$conf->[$in{'index'}]->{'values'}};
	}

print &ui_form_start("save_headeracc.cgi", "post");
if (@v) {
	print &ui_hidden("index", $in{'index'});
	}
print &ui_hidden("type", $in{'type'});
print &ui_table_start($text{'header_header'}, undef, 2);

# Header name
print &ui_table_row($text{'header_name'},
	&ui_textbox("name", $v[0], 30));

# Allow or deny ACLs
print &ui_table_row($text{'ahttp_a'},
	&ui_radio("action", $v[1] || "allow",
		  [ [ "allow", $text{'ahttp_a1'} ],
		    [ "deny", $text{'ahttp_d'} ] ]));

# Get list of ACLs being matched, and all ACLs
my (@yes, @no);
for(my $i=2; $i<@v; $i++) {
	if ($v[$i] =~ /^!(.*)/) {
		push(@no, $1);
		}
	else {
		push(@yes, $v[$i]);
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
		     @v ? ( [ 'delete', $text{'buttdel'} ] ) : ( ) ]);

&ui_print_footer("list_headeracc.cgi", $text{'header_return'},
	"", $text{'index_return'});

