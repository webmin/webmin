
require './mysql-lib.pl';

sub show_charset
{
local ($value) = @_;
local $main::error_must_die = 1;
local @charsets;
eval { @charsets = &list_character_sets(); };
if (@charsets) {
	@charsets = sort { $a->[1] cmp $b->[1] } @charsets;
	return &ui_select("charset", $value,
			  [ [ "", "&lt;$text{'default'}&gt;" ], @charsets ]);
	}
else {
	return &ui_opt_textbox("charset", $value, 20, $text{'default'});
	}
}

sub parse_charset
{
if ($in{'charset_def'}) {
	return undef;
	}
else {
	$in{'charset'} =~ /^\S*$/ || &error($text{'config_echarset'});
	return $in{'charset'};
	}
}
