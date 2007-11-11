#!/usr/local/bin/perl
# Search Webmin modules and help pages and text and config.info

do './web-lib.pl';
&init_config();
do './ui-lib.pl';
&ReadParse();
&load_theme_library();
%text = &load_language($current_theme);

$prod = &get_product_name();
$ucprod = ucfirst($prod);
&ui_print_header(undef, &text('search_title', $ucprod), "", undef, 0, 1);

# XXX what if nothing was entered?
$re = $in{'search'};

print &ui_columns_start([ $text{'search_what'},
			  $text{'search_type'},
			  $text{'search_text'} ]);

# Search module names first
@mods = &get_available_module_infos();
foreach $m (@mods) {
	if ($m->{'desc'} =~ /\Q$re\E/i || $m->{'dir'} =~ /\Q$re\E/i) {
		print &ui_columns_row([
			"<a href='$m->{'dir'}/'>$m->{'desc'}</a>",
			&text('search_mod', $ucprod),
			$m->{'desc'} =~ /\Q$re\E/i ?
				&highlight_text($m->{'desc'}) :
				&highlight_text($m->{'dir'}),
			]);
		}
	}

# Then do module configs
foreach $m (@mods) {
	%access = &get_module_acl(undef, $m);
	next if ($access{'noconfig'});
	$file = $prod eq 'webmin' ? "$m->{'dir'}/config.info"
				  : "$m->{'dir'}/uconfig.info";
	%info = ( );
	@info_order = ( );
	&read_file($file, \%info, \@info_order);
	foreach $o (@lang_order_list) {
		&read_file("$file.$o", \%info);
		}
	foreach $c (@info_order) {
		@p = split(/,/, $info{$c});
		if ($p[0] =~ /\Q$re\E/i) {
			print &ui_columns_row([
				"<a href='config.cgi?$m->{'dir'}'>$m->{'desc'}</a>",
				$text{'search_config_'.$prod},
				&highlight_text($p[0]),
				]);
			}
		}
	}

# Then do help pages

# Then do text strings

print &ui_columns_end();

&ui_print_footer();

# Returns text with the search term bolded, and truncated to 60 characters
sub highlight_text
{
local ($str, $len) = @_;
$len ||= 60;
if ($str =~ /^(.*)(\Q$re\E)(.*)$/i) {
	$str = $1."<b>".$2."</b>".$3;
	if (length($str) > $len) {
		$str = substr($str, (length($str)-$len)/2, $len);
		$str = "... ".$str." ...";
		}
	}
return $str;
}

