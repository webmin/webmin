#!/usr/local/bin/perl
# A form for editing or creating a refresh pattern rule

use strict;
use warnings;
our (%text, %in, %access, $squid_version, %config);
require './squid-lib.pl';
$access{'refresh'} || &error($text{'refresh_ecannot'});
&ReadParse();
my $conf = &get_config();

my @v;
if (!defined($in{'index'})) {
	&ui_print_header(undef, $text{'refresh_create'}, "",
		undef, 0, 0, 0, &restart_button());
	}
else {
	&ui_print_header(undef, $text{'refresh_edit'}, "",
		undef, 0, 0, 0, &restart_button());
	@v = @{$conf->[$in{'index'}]->{'values'}};
	}

print &ui_form_start("save_refresh.cgi", "post");
if (@v) {
	print &ui_hidden("index", $in{'index'});
	}
print &ui_table_start($text{'refresh_header'}, undef, 4);

# Show regular expression inputs
my $caseless;
if ($v[0] eq "-i") {
	$caseless = shift(@v);
	}
print &ui_table_row($text{'refresh_re'},
	&ui_textbox("re", $v[0], 40)."<br>\n".
	&ui_checkbox("caseless", 1, $text{'refresh_caseless'}, $caseless));

# Show min, max and percentage
print &ui_table_row($text{'refresh_min'},
	&ui_textbox("min", $v[1], 6)." ".$text{'ec_mins'});

print &ui_table_row($text{'refresh_max'},
	&ui_textbox("max", $v[3], 6)." ".$text{'ec_mins'});

$v[2] =~ s/\%$//;
print &ui_table_row($text{'refresh_pc'},
	&ui_textbox("pc", $v[2], 6)." %");

# Show options
my %opts = map { $_, 1 } @v[4..$#v];
my @known = ( "override-expire", "override-lastmod",
	      "reload-into-ims", "ignore-reload" );
print &ui_table_row($text{'refresh_options'},
	join("<br>\n", map { &ui_checkbox("options", $_, $text{'refresh_'.$_},
					  $opts{$_}) } @known), 3);
foreach my $k (keys %opts) {
	print &ui_hidden("options", $k) if (&indexof($k, @known) < 0);
	}

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'buttsave'} ],
		     @v ? ( [ 'delete', $text{'buttdel'} ] ) : ( ) ]);

&ui_print_footer("list_refresh.cgi", $text{'refresh_return'},
	"", $text{'index_return'});

